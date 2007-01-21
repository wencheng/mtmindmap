package Mindmap;
use strict;
use base 'MT::App';
use GD;
use GD::Polyline;

sub pow { abs($_[0]) * $_[0] };
sub floor { $_[0]*10%10 ? (($_[0]*10+10)-($_[0]*10%10))/10 : $_[0] };
sub max { $_[0]>$_[1] ? $_[0] : $_[1] }

use constant PI => 4 * atan2( 1, 1 );
use constant DEBUG => 0;

sub init {
	my $self = shift;
	$self->SUPER::init(@_) or return;
	$self->add_methods(
		view => \&view,
		rebuild => \&rebuild,
	);
	$self->{default_mode}   = 'view';
	$self->{requires_login} = 1;

	$self->{_xlen} = undef;
	$self->{_ylen} = undef;
	$self->{_ctgs} = undef;
	$self->{_maxlvl} = undef;
	bless $self, 'Mindmap';

	return $self;
}

# FOR LOCAL DEBUG ONLY
sub new {
	if ( DEBUG ) {
		my $class = shift;
		my $self = {
				_xlen   => undef,
				_ylen   => undef,
				_ctgs => undef,
				_maxlvl => undef,
			};
		bless $self, $class;
	
		$self;
	} else {
		shift->SUPER::new(@_) or return;
	}
}

sub font {
	if ( DEBUG ) {
		'/Applications/Microsoft Office 2004/Office/Fonts/MS PGothic.ttf';
	} else {
		'/usr/share/fonts/truetype/kochi/kochi-mincho.ttf';
	}
}

sub ctgs {
	my ( $self, $var ) = @_;
	$self->{_ctgs} = $var if defined($var);
	return $self->{_ctgs};
}

sub maxlvl {
	my ( $self, $var ) = @_;
	$self->{_maxlvl} = $var if defined($var);
	return $self->{_maxlvl};
}

sub xlen {
	my ( $self, $var ) = @_;
	$self->{_xlen} = $var if defined($var);
	return $self->{_xlen};
}

sub ylen {
	my ( $self, $var ) = @_;
	$self->{_ylen} = $var if defined($var);
	return $self->{_ylen};
}

sub xcenter { shift->{_xlen} / 2; }

sub ycenter { shift->{_ylen} / 2; }

sub plugin {
	MT::Plugin::Mindmap->instance;
}

sub view {
	my $self   = shift;
	
	my $blog   = MT->instance->blog;
	my $config = MT::Plugin::Mindmap->instance->get_config_hash('blog:'.$blog->id);
	
	my $param  = {};
	$param->{version} = $MT::Plugin::Mindmap::VERSION;
	$param->{blog_name} = $blog->name;

	if ( DEBUG ) {
		use Data::Dumper;
		$param->{ctgs_dump} = Dumper( $self->_get_categories() );

		# rebuild everytime
		$self->build;
	}

	# Set breadcrumb
	$self->_add_breadcrumb();

	$self->build_page( 'view.tmpl', $param );
}

sub rebuild {
	my $self = shift;
	$self->build();
	$self->view();
}

sub build {
	my $self = shift;

	# fetch categories
	$self->_get_categories();

	# generate mindmap image
	$self->_create_image();
}

sub _get_categories {
	my $self = shift;
	my $parent = shift || 0;

	# fetch all category
	my @cats = (
		map { {
				id        => $_->id,
				blog_id   => $_->blog_id,
				label     => $_->label,
				author_id => $_->author_id,
				parent    => $_->parent,
		}, } MT::Category->load( { blog_id => MT->instance->blog->id } )
	);

	my %children;
	foreach my $cat (@cats) {
		push @{ $children{ ( $cat->{parent} ) ? $cat->{parent} : '0' } }, $cat;
	}
	foreach my $i ( keys %children ) {
		@{ $children{$i} } =
		  sort { $a->{label} cmp $b->{label} } @{ $children{$i} };
	}

	# return categories as a tree from root(whose parent is 0)
	my @ctgs;
	foreach my $i (@cats) {
		$i->{children} = $children{ $i->{id} };
		push( @ctgs, $i ) if $i->{parent} == 0;
	}

	$self->ctgs( \@ctgs );

	$self->maxlvl( _get_deepest_level( \@ctgs, 1 ) );

	return \@ctgs;
}

sub _get_deepest_level {
	my $ctgs = shift;
	my $level = shift;
	
	my $max = $level;
	foreach my $i (@$ctgs) {
		$i->{level} = $level;
		$max = _get_deepest_level( $i->{children}, $level+1 ) if $i->{children};
	}

	return $max;
}

sub _prepare_image_attrs {
	my $self = shift;

	my @total_leaf = ();
	for ( 0..$#{$self->ctgs} ) {
		$total_leaf[$_] = ( @{$self->ctgs}[$_]->{children} ) ?
			_get_total_leaf( @{$self->ctgs}[$_]->{children} ) : 0;
	}

	my $sum_l = 0;
	my $sum_r = 0;
	for ( 0..floor(($#{$self->ctgs}+1)/2)-1 ) {
		$sum_l += $total_leaf[$_];
	}
	for ( floor(($#{$self->ctgs}+1)/2)..$#{$self->ctgs} ) {
		$sum_r += $total_leaf[$_];
	}

	print $sum_l, $sum_r;
	$self->ylen( max( $sum_l, $sum_r ) * 60 );
}

sub _prepare_image_attr {
	my $node = shift;

	return 1 unless ( $node->{childern} );
	
	my $leaf_sum = 0;
	my $max_leaf = 0;
	for ( @{ $node->{children} } ) {
		$leaf_sum += _prepare_image_attr( $_  ); 
	}

	return $leaf_sum;
}

sub _create_image {
	my $self = shift;
	my $blog = MT->instance->blog;

	return if ( $self->ctgs == undef );

	# arrange picture size
	$self->xlen( $self->maxlvl * 90 * 2 + 120 );
	$self->ylen( 480 );
	#$self->_calculate_ylen();

	my $img   = new GD::Image( $self->xlen, $self->ylen );
	my $color = Mindmap->_init_colors($img);

	#$img->transparent( $color->{white} );
	$img->interlaced('true');

	# border
	$img->rectangle( 0, 0, $self->xlen - 1, $self->ylen - 1, $color->{black} );

	# blog name
	my $cfg = $self->plugin->get_config_hash('blog:'.$blog->id);
	if ( $cfg->{show_blog_name} ) {
		$img->stringFT(	$color->{black}, font, 10, 0, 10, 11, $blog->name );
	}

	# version info
	$img->stringFT(	$color->{black}, font, 10, 0, 10, 21,
		'by MovebleType Mindmap ' . $MT::Plugin::Mindmap::VERSION );

	$self->_draw_top_branch( $img, $color );

	# center
	$img->arc( $self->xcenter, $self->ycenter, 100 + $_, 100 + $_, 0, 360,
		$color->{brown} ) for ( -4 .. 4 );

	# $img->rectangle( $self->xcenter-30, $self->ycenter-10, $self->xcenter+30, $self->ycenter+10, $color->{brown} );
	$img->stringFT(
		$color->{brown}, font, 10, 0,
		$self->xcenter - 26,
		$self->ycenter + 4,
		'Mind Map'
	);

	if ( DEBUG ) {
		$img->line( 10, 20, 54, 20, $color->{black} );
		$img->stringFT(	$color->{black}, font, 10, 0, 10, 31, "あいうえお" );
		$self->_save_image( $img, '.' );
	} else {
		$self->_save_image( $img, MT->instance->blog->site_path );
	}
}

sub _draw_top_branch {
	my $self = shift;
	my $img  = shift;
	my $c    = shift;

	my $ctgs = $self->ctgs;

	# angle on the center circle
	my $agl = 2 * PI() / ( $#$ctgs + 1 );

	# customized rotate
	my $rotate = 2 * PI() / 2;
	$rotate += $agl / 2 if ( $#$ctgs % 2 );

	for my $i ( 0 .. $#$ctgs ) {
		my $sx = sin( $agl * $i + $rotate ) * 50 + $self->xcenter;
		my $sy = cos( $agl * $i + $rotate ) * 50 + $self->ycenter;
		my $ex = $sx > $self->xcenter() ? $sx + 90 : $sx - 90;
		my $ey = $sy > $self->ycenter() ? $sy + 50 : $sy - 50;

		# draw branch line
		# $i%4+1: skip color white
		$self->_draw_top_branch_line( $img, $sx, $sy, $ex, $ey, $i%4+1 );

		# draw branch label
		my $text = @$ctgs[$i]->{label};
		my $fs   = 10;
		$img->stringFT( $c->{black}, font, $fs, 0,
			$ex > $self->xcenter() ? $ex - ($fs+1) * length($text)/2 - 3 : $ex + 3,
			$ey - 3, $text );

		# draw children
		my $children_color = [0];
		for (1..4) {
			push( @$children_color, $_ ) if $_ != $i%4+1;
		}
		$self->_draw_children( $img, $c, $children_color, @$ctgs[$i]->{children}, $ex, $ey>$self->ycenter?$ey+3:$ey-3 )
		  if @$ctgs[$i]->{children};
	}
}

sub _draw_children {
	my $self = shift;
	my $img  = shift;
	my $full_color  = shift;
	my $c    = shift;
	my $ctgs = shift;
	my $sx   = shift;
	my $sy   = shift;

	for my $i ( 0 .. $#$ctgs ) {
		my $ex = $sx > $self->xcenter() ? $sx + 90 : $sx - 90;
		my $ey = $sy + 50 * ( $i - $#$ctgs / 2 );
		$ey = $sy - 15 if ( $#$ctgs == 0 );

		# draw branch line
		# $i%3+1: skip color white and color of parent
		$self->_draw_top_branch_line( $img, $sx, $sy, $ex, $ey, @$c[$i%3+1] );

		# draw branch label
		my $text = @$ctgs[$i]->{label};
		my $fs   = 10;
		$img->stringFT( $full_color->{black}, font, $fs, 0,
			$ex > $self->xcenter() ? $ex - ($fs+1) * length($text) / 2 - 3 : $ex + 3,
			$ey - 3, $text );

		# draw children
		my $children_color = [0];
		for (1..4) {
			push( @$children_color, $_ ) if $_ !=  @$c[$i%3+1];
		}
		$self->_draw_children( $img, $full_color, $children_color, @$ctgs[$i]->{children}, $ex, $ey )
		  if @$ctgs[$i]->{children};
	}
}

sub _draw_top_branch_line {
	my $self = shift;
	my $img   = shift;
	my $sx    = shift;
	my $sy    = shift;
	my $ex    = shift;
	my $ey    = shift;
	my $color = shift;

	for my $i ( -3 .. 3 ) {
		my $poly = new GD::Polyline;
		$poly->addPt( $sx + $i, $sy );
		
		my $x =	($ey-$sy)*2/10;
		$x = -$x if ( ($ex>$sx&&$ey<$sy) || ($ex<$sx&&$ey>$sy) );
		$x += $sx+$i;
		my $y = $ey>$sy ? $ey-10 : $ey+10; 
		$img->line( $x-2, $y, $x+2, $y, $color );
		$img->line( $x, $y-2, $x, $y+2, $color );
		$poly->addPt( $x, $y );

		$poly->addPt( $ex + $i, $ey );
		$img->polyline( $poly->addControlPoints()->toSpline(), $color );
	}
}

sub _save_image {
	my ( $self, $img, $path ) = @_;

	# Save picture
	open( PICTURE, ">$path/ctg_mindmap.png" )
	  or die("Cannot open file for writing");

	# Make sure we are writing to a binary stream
	binmode PICTURE;

	# Convert the image to PNG and print it to the file PICTURE
	print PICTURE $img->png;
	close PICTURE;
}

sub _init_colors {
	my ( $self, $im ) = @_;

	my $blog;
	if ( not DEBUG ) {
		$blog = MT->instance->blog;
	}
	my $cfg;
	if ( not DEBUG ) {
		$cfg = $self->plugin->get_config_hash('blog:'.$blog->id);
	} else {
		$cfg = {
			color1_r => 255,
			color1_g => 80,
			color1_b => 80,
			color2_r => 255,
			color2_g => 220,
			color2_b => 80,
			color3_r => 100,
			color3_g => 100,
			color3_b => 255,
			color4_r => 80,
			color4_g => 255,
			color4_b => 80,
		};
	}
	
	# Allocate colors
	my $color =  {
		white => $im->colorAllocate( 255, 255, 255 ),

		clr1 => $im->colorAllocate( $cfg->{color1_r}, $cfg->{color1_g}, $cfg->{color1_b} ),
		clr2 => $im->colorAllocate( $cfg->{color2_r}, $cfg->{color2_g}, $cfg->{color2_b} ),
		clr3 => $im->colorAllocate( $cfg->{color3_r}, $cfg->{color3_g}, $cfg->{color3_b} ),
		clr4 => $im->colorAllocate( $cfg->{color4_r}, $cfg->{color4_g}, $cfg->{color4_b} ),

		brown  => $im->colorAllocate( 255, 0x99, 0 ),
		violet => $im->colorAllocate( 255, 0,    255 ),

		black => $im->colorAllocate( 0, 0, 0 ),
	};
}

sub _add_breadcrumb {
	my $self = shift;

	my $blog    = MT->instance->blog;
	my $blog_id = $blog->id;

	$self->add_breadcrumb( $self->plugin->translate("Main Menu"),
		$self->mt_uri );
	$self->add_breadcrumb( $blog->name,
		$self->mt_uri( mode => 'menu', args => { blog_id => $blog_id } ) );
	$self->add_breadcrumb( $self->plugin->translate('Mindmap'), $self->uri );
}

# GD::Image demo
sub _create_image_test {
	my ( $self, $ctgs ) = @_;

	# Create a new image
	my $img = new GD::Image( 640, 400 );

	# Allocate some colors
	my $color = $self->_init_colors($img);

	# Make the background transparent and interlaced
	$img->transparent( $color->{white} );
	$img->interlaced('true');

	my $x1 = 10;
	my $y1 = 10;
	my $x2 = 200;
	my $y2 = 200;

	# Draw a border
	$img->rectangle( 0, 0, 639, 399, $color->{black} );

	# A line
	$img->line( $x1, $y1, $x2, $y2, $color->{red} );

	# A Dashed Line
	$img->dashedLine( $x1 + 100, $y1, $x2, $y2, $color->{blue} );

	# Draw a rectangle
	$img->rectangle( $x1 + 200, $y1, $x2 + 200, $y2, $color->{green} );

	# A filled rectangle
	$img->filledRectangle( $x1 + 400, $y1, $x2 + 400, $y2, $color->{brown} );

	# A circle
	$img->arc( $x1 + 100, $y1 + 200 + 100, 50, 50, 0, 360, $color->{violet} );

	# A polygon
	# Make the polygon
	my $poly = new GD::Polyline;
	$poly->addPt( $x1 + 200, $y1 + 200 );
	$poly->addPt( $x1 + 250, $y1 + 230 );
	$poly->addPt( $x1 + 300, $y1 + 310 );
	$poly->addPt( $x1 + 400, $y1 + 300 );

	# Draw it
	$img->polygon( $poly, $color->{yellow} );
	my $spline = $poly->addControlPoints()->toSpline();
	$img->polyline( $spline, $color->{red} );

	# Create a Border around the image
	$img->rectangle( 0, 0, 199, 79, $color->{black} );
	$x1 = 2;
	$y1 = 2;

	# Draw text in small font
	$img->string( gdSmallFont, $x1, $y1, "small font", $color->{blue} );
	$img->string( gdMediumBoldFont, $x1, $y1 + 20, "Medium Bold Font",
		$color->{green} );
	$img->string( gdLargeFont, $x1, $y1 + 40, "Large font", $color->{red} );
	$img->string( gdGiantFont, $x1, $y1 + 60, "Giant font", $color->{black} );

	my $font = '/usr/share/fonts/truetype/kochi/kochi-mincho.ttf';
	$img->stringFT( $color->{red}, $font, 10, 0, $x1, $y1 + 100,
		@$ctgs[1]->{label} );
	$img->stringFT( $color->{red}, $font, 10, 0, $x1, $y1 + 120,
		@$ctgs[2]->{label} );

	# Fill the area with red
	#$img->fill( 50, 50, $color->{red} );

	# /home/apache2/wwwroot/wencheng.fang.sh.cn/wwwroot/caesar/
	$self->_save_image( $img, MT->instance->blog->site_path );
}

1;

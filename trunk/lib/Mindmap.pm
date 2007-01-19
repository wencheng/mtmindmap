package Mindmap;
use strict;
use base 'MT::App';
use GD;
use GD::Polyline;

use constant PI => 4*atan2(1,1);

sub init {
	my $self = shift;
	$self->SUPER::init(@_) or return;
	$self->add_methods( view => \&view, );
	$self->{default_mode}   = 'view';
	$self->{requires_login} = 1;
	
	return $self;
}

# FOR LOCAL DEBUG
sub new {
	my $class = shift;
	
	my $self = {
		_xlen => undef,
		_ylen => undef,
		_maxlvl => undef,
	};
	bless $self, $class;
	
	$self;
}

sub font {
	#'/usr/share/fonts/truetype/kochi/kochi-mincho.ttf';
	'/Applications/Microsoft Office 2004/Office/Fonts/MS PGothic.ttf';
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

sub xcenter { shift->{_xlen}/2; }

sub ycenter { shift->{_ylen}/2; }

sub plugin {
	MT::Plugin::Mindmap->instance;
}

sub view {
	my $self    = shift;
	my $config = MT::Plugin::Mindmap->instance->get_config_hash('system');
	my $blog   = MT->instance->blog;
	my $param  = {};

	# fetch all category
	my %children;
	my @cats = MT::Category->load({ blog_id => $blog->id });
    foreach my $cat (@cats) {
        push @{$children{($cat->parent) ? $cat->parent : '0'}}, $cat;
    }

    foreach my $i (keys %children) {
        @{$children{$i}} = sort { $a->label cmp $b->label } @{$children{$i}};
    }

	$param->{text}    = $config->{text};
	$param->{version} = $MT::Plugin::Mindmap::VERSION;
	$param->{blog_id} = $blog->name;
	$param->{ctgs}    = [
		map {
			{
				id        => $_->id,
				blog_id   => $_->blog_id,
				label     => $_->label,
				author_id => $_->author_id,
				parent    => $_->parent,
			}
		  } @cats
	];
	$self->maxlvl( 3 );

	$self->_create_image( $param->{ctgs} );

	# Set breadcrumb
	$self->_add_breadcrumb();

	$self->build_page( 'view.tmpl', $param );
}

sub _create_image {
	my ($self, $ctgs) = @_;
	
	return if ( $ctgs == undef );

	# arrange picture size
	$self->xlen( $self->maxlvl*90*2+120 );
	$self->ylen( 480 );

	my $img = new GD::Image( $self->xlen, $self->ylen );
	my $color = Mindmap->_init_colors($img);
	#$img->transparent( $color->{white} );
	$img->interlaced('true');

	# border
	$img->rectangle( 0, 0, $self->xlen-1, $self->ylen-1, $color->{black} );

	$self->_draw_top_branch( $img, $color, $ctgs );

	# center 
	$img->arc( $self->xcenter, $self->ycenter, 100+$_, 100+$_, 0, 360, $color->{brown} ) for (-4..4);
	#$img->rectangle( $self->xcenter-30, $self->ycenter-10, $self->xcenter+30, $self->ycenter+10, $color->{brown} );
	$img->stringFT($color->{brown}, font, 10, 0, $self->xcenter-26, $self->ycenter+4, 'Mind Map');


	#_draw_branch( $img, $color->{red}, @$ctgs[0]->{label} );
	
	# /home/apache2/wwwroot/wencheng.fang.sh.cn/wwwroot/caesar/
	#_save_image( $img, MT->instance->blog->site_path );
	$self->_save_image( $img, '.' );
}

sub _draw_top_branch {
	my $self = shift;
	my $img = shift;
	my $c = shift;
	my $ctgs = shift;

	# angle on the center circle 
	my $agl = 2 * PI() / ($#$ctgs+1);
	
	# customized rotate
	my $rotate = 2 * PI() / 2;
	$rotate += $agl/2 if ($#$ctgs%2);

	for my $i (0..$#$ctgs) {
		my $sx = sin($agl*$i+$rotate)*50 + $self->xcenter;
		my $sy = cos($agl*$i+$rotate)*50 + $self->ycenter;
		my $ex = $sx > $self->xcenter() ? $sx+90 : $sx-90;
		my $ey = $sy > $self->ycenter() ? $sy+50 : $sy-50;

		# draw branch line
		# $i+1: skip color white
		_draw_top_branch_line( $img, $sx, $sy, $ex, $ey, $i+1 );
		
		# draw branch label
		my $text = @$ctgs[$i]->{label};
		my $fs = 10;
		$img->stringFT( $c->{black}, font, $fs, 0,
			$ex>$self->xcenter()?$ex-$fs*length($text)/2:$ex+3 , $ey-3, $text );
			
		# draw children
		$self->_draw_children( $img, $c, @$ctgs[$i]->{children}, $ex, $ey )
			if @$ctgs[$i]->{children};
	}
}

sub _draw_children {
	my $self = shift;
	my $img = shift;
	my $c = shift;
	my $ctgs = shift;
	my $sx = shift;
	my $sy = shift;

	for my $i (0..$#$ctgs) {
		my $ex = $sx > $self->xcenter() ? $sx+90 : $sx-90;
		my $ey = $sy + 50*($i-$#$ctgs/2);
		$ey = $sy-15 if ($#$ctgs == 0); 

		# draw branch line
		# $i+1: skip color white
		_draw_top_branch_line( $img, $sx, $sy, $ex, $ey, $i+1 );
		
		# draw branch label
		my $text = @$ctgs[$i]->{label};
		my $fs = 10;
		$img->stringFT( $c->{black}, font, $fs, 0,
			$ex>$self->xcenter()?$ex-$fs*length($text)/2:$ex+3 , $ey-3, $text );

		# draw children
		$self->_draw_children( $img, $c, @$ctgs[$i]->{children}, $ex, $ey )
			if @$ctgs[$i]->{children};
	}
}

sub _draw_top_branch_line {
	my $img = shift;
	my $sx = shift;
	my $sy = shift;
	my $ex = shift;
	my $ey = shift;
	my $color = shift;

	for my $i (-3..3) {
		my $poly = new GD::Polyline;
		$poly->addPt( $sx+$i , $sy );
		$poly->addPt( $sx+($ex-$sx)*1/4+$i , $sy+($ey-$sy)/2*3/2 );
		$poly->addPt( $ex+$i , $ey );
		$img->polyline( $poly->addControlPoints()->toSpline(), $color );
	}
}

sub _save_image {
	my ($self, $img, $path) = @_;

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
	my ($self, $im) = @_;

	# Allocate colors
	return {
		white => $im->colorAllocate( 255, 255, 255 ),

		red   => $im->colorAllocate( 255, 0,   0 ),
		blue  => $im->colorAllocate( 0,   0,   255 ),
		green => $im->colorAllocate( 0,   255, 0 ),
		yellow => $im->colorAllocate( 255, 255,  0 ),

		brown  => $im->colorAllocate( 255, 0x99, 0 ),
		violet => $im->colorAllocate( 255, 0,    255 ),

		black => $im->colorAllocate( 0,   0,   0 ),
	};
}

sub _add_breadcrumb {
	my $self = shift;

	my $blog    = MT->instance->blog;
	my $blog_id = $blog->id;

	$self->add_breadcrumb( $self->plugin->translate("Main Menu"), $self->mt_uri );
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

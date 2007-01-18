package Mindmap;
use strict;
use base 'MT::App';
use GD;
use GD::Polyline;

sub init {
	my $app = shift;
	$app->SUPER::init(@_) or return;
	$app->add_methods( view => \&view, );
	$app->{default_mode}   = 'view';
	$app->{requires_login} = 1;
	$app;
}

sub plugin {
	MT::Plugin::Mindmap->instance;
}

sub view {
	my $app    = shift;
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

	$app->_create_image( $param->{ctgs} );

	# Set breadcrumb
	$app->_add_breadcrumb();

	$app->build_page( 'view.tmpl', $param );
}

sub _create_image {
	my ( $app, $ctgs ) = @_;

	my $xlen    = 640;
	my $ylen    = 480;
	my $xcenter = $xlen / 2;
	my $ycenter = $ylen / 2;

	my $font  = '/usr/share/fonts/truetype/kochi/kochi-mincho.ttf';
	my $img   = new GD::Image( $xlen, $ylen );
	my $color = _init_colors($img);
	$img->transparent( $color->{white} );
	$img->interlaced('true');

	# border
	$img->rectangle( 0, 0, $xlen - 1, $ylen - 1, $color->{black} );

	# center box
	$img->rectangle(
		$xcenter - 30,
		$ycenter - 10,
		$xcenter + 30,
		$ycenter + 10,
		$color->{brown}
	);
	$img->stringFT(
		$color->{brown}, $font, 10, 0,
		$xcenter - 26,
		$ycenter + 4,
		'Mind Map'
	);

	# /home/apache2/wwwroot/wencheng.fang.sh.cn/wwwroot/caesar/
	_save_image( $img, MT->instance->blog->site_path );
}

sub _create_image_test {
	my ( $app, $ctgs ) = @_;

	# Create a new image
	my $img = new GD::Image( 640, 400 );

	# Allocate some colors
	my $color = $app->_init_colors($img);

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
	$app->_save_image( $img, MT->instance->blog->site_path );
}

sub _save_image {
	my ($app, $img, $path) = @_;

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
	my ($app, $im) = @_;

	# Allocate colors
	return {
		white => $im->colorAllocate( 255, 255, 255 ),
		black => $im->colorAllocate( 0,   0,   0 ),
		red   => $im->colorAllocate( 255, 0,   0 ),
		blue  => $im->colorAllocate( 0,   0,   255 ),
		green => $im->colorAllocate( 0,   255, 0 ),

		brown  => $im->colorAllocate( 255, 0x99, 0 ),
		violet => $im->colorAllocate( 255, 0,    255 ),
		yellow => $im->colorAllocate( 255, 255,  0 ),
	};
}

sub _add_breadcrumb {
	my $app = shift;

	my $blog    = MT->instance->blog;
	my $blog_id = $blog->id;

	$app->add_breadcrumb( $app->plugin->translate("Main Menu"), $app->mt_uri );
	$app->add_breadcrumb( $blog->name,
		$app->mt_uri( mode => 'menu', args => { blog_id => $blog_id } ) );
	$app->add_breadcrumb( $app->plugin->translate('Mindmap'), $app->uri );
}

1;

# Copyright 2007 Wencheng Fang
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package Mindmap;
use strict;
use base 'MT::App';
use POSIX;
use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use MT::I18N::ja;
use GD;
use GD::Polyline;

use constant PI => 4 * atan2( 1, 1 );
use constant ENTRY_HEIGHT => 20;
use constant BLACK => 5;
use constant VOILET => 7;
use constant DEBUG => 0;
#use constant DEBUG => 1;

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
	$self->{_xcenter} = undef,
	$self->{_ycenter} = undef,
	$self->{_ctgs} = undef;
	$self->{_entries} = [];
	bless $self, 'Mindmap';

	return $self;
}

# FOR LOCAL TEST ONLY
sub new {
	if ( DEBUG ) {
		my $class = shift;
		my $self = {
				_xlen   => undef,
				_ylen   => undef,
				_xcenter => undef,
				_ycenter => undef,
				_ctgs => undef,
				_entries => [],
			};
		bless $self, $class;

		$self;
	} else {
		shift->SUPER::new(@_) or return;
	}
}

sub plugin {
	MT::Plugin::Mindmap->instance;
}

sub view {
	my $self = shift;

	$self->build() if ( not -e static_filepath );

	my $spath = MT->instance->blog->site_url;
    $spath =~ s/\/*$//g;

	$self->redirect( "${spath}/mindmap.html" );
}

sub rebuild {
	my $self = shift;
	$self->build();
	$self->view();
}

sub build {
	my $self = shift;

	# fetch categories
	$self->_load_categories();

	# fetch entries
	my $cfg = $self->plugin->get_config_hash('blog:'.MT->instance->blog->id);
	$self->_load_entries() if $cfg->{show_entry};

	# generate mindmap image
	$self->_create_image();

    # save static html
    $self->_save();
}

sub _save {
	my $self = shift;
	
    my $tmpl = $self->load_tmpl( 'view.tmpl' );
    # Template path is not approperiate when callback excuting
    # Anyone has a better idea?
    $tmpl = $self->load_tmpl( $self->app_dir.'/plugins/Mindmap/tmpl/view.tmpl' ) if (!$tmpl);
    return $self->error( $self->plugin->translate("Loading template 'view.tmpl' failed: [_2]",
    	$@) ) if (!$tmpl);

	# params
	my $blog = MT->instance->blog;
	$tmpl->param( version => $MT::Plugin::Mindmap::VERSION );
	$tmpl->param( blog_name => $blog->name );
	$tmpl->param( blog_id => $blog->id );
	$tmpl->param( site_url => $blog->site_url );
	$tmpl->param( entries => $self->entries );

	# Set breadcrumb
	$self->_add_breadcrumb();

	# Write file
    my $spath = $blog->site_path;
    $spath =~ s/\/*$/\//g;
    open F, "> ".static_filepath()
        or $self->error( $self->plugin->translate("Write '[_1]' failed",static_filepath()) );
	print F $self->translate_templatized($tmpl->output);
    close F;
}

# passthru for L10N
sub translate_templatized {
    my $app = shift;
    $app->plugin->translate_templatized(@_);
}

sub static_filepath {
	my $spath = MT->instance->blog->site_path;
    $spath =~ s/\/*$/\//g;
	"${spath}mindmap.html";
}

sub font {
	if ( DEBUG ) {
		'/Applications/Microsoft Office 2004/Office/Fonts/MS PGothic.ttf';
	} else {
		my $cfg = MT::Plugin::Mindmap->instance->get_config_hash('blog:'.MT->instance->blog->id);
		return $cfg->{font};
	}
}

sub _getset {
    my $p = (caller(1))[3]; $p =~ s/.*:://;
    @_ > 1 ? $_[0]->{"_$p"} = $_[1] : $_[0]->{"_$p"};
}

sub ctgs { &_getset }
sub entries { &_getset }
sub xlen { &_getset }
sub ylen { &_getset }
sub xcenter { &_getset }
sub ycenter { &_getset }

# fetch all entries of the category specified
sub _load_entries {
	my $self = shift;
	my $ctgs = shift || $self->ctgs;

	my @entries = ();
	for my $ctg (@$ctgs) {
		$ctg->{entries} = [
			map { {
				id        => $_->id,
				title     => $_->title,
				permalink => $_->permalink,
				status    => $_->status,
			}, } MT::Entry->load( {
					blog_id => MT->instance->blog->id,
#					category_id => $ctg->{id},
				}, {
					'join' => [ 'MT::Placement', 'entry_id', {category_id => $ctg->{id}} ] 
				}
			)
		];

		$self->_load_entries( $ctg->{children} ) if $ctg->{children};
	}
}

sub _load_categories {
	my $self = shift;

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

	return \@ctgs;
}

sub _prepare_image_attr {
	my $node = shift;
	my $parent = shift;

	# for all nodes and leafs
	$node->{level} = $parent ? $parent->{level}+1 : 1; 
	$node->{parent} = $parent;

	# for leaf
	if ( not $node->{children} ) {
		$node->{height} = 60 + ($#{ $node->{entries} }+1)*(ENTRY_HEIGHT+4);
		return 0;
	}

	# for node who has leaf(s)
	my $max_leafs = 0;
	for my $i ( 0..$#{ $node->{children} } ) {
		$max_leafs += _prepare_image_attr( ${ $node->{children} }[$i], $node );
	}

	if ( $max_leafs ) {
		$node->{height} += $_->{height} for ( @{ $node->{children} } );
	} else {
		# all children are leafs
		$node->{height} += $_->{height} for ( @{ $node->{children} } );
	}
	$node->{height} += ($#{ $node->{entries} }+1)*ENTRY_HEIGHT;

	$node->{max_leafs} = $max_leafs ? $max_leafs : $#{ $node->{children} };
}

sub _preload {
	my $self = shift;

	my $ctgs = $self->ctgs;
	return if $#$ctgs < 0;

	# angle on the center circle
	my $agl = 2 * PI() / ( $#$ctgs + 1 );

	# customized rotate
	my $rotate = 2 * PI() / 2;
	$rotate += $agl / 2;

	my $half = ceil(($#$ctgs+1)/2);

	# left half
	my $ey = 0;
	for my $i ( 0 .. $half-1 ) {
		# branch line
		my $sx = sin( $agl * $i + $rotate ) * 50 + $self->xcenter;
		my $sy = cos( $agl * $i + $rotate ) * 50 + $self->ycenter;
		
		if ( $i ) {
			$ey += ( @$ctgs[$i-1]->{height} + @$ctgs[$i]->{height} )/2;
			$ey = $sy+1 if $ey < $sy;
		} else {
			$ey = $sy - @$ctgs[$i]->{height}/2;
		}
	
		my $ex = $sx - 90;
		my $x = abs($ey-$sy)/5;
 		$ex = $sx-$x-3 if $x > 90;

		@$ctgs[$i]->{sx} = $sx;
		@$ctgs[$i]->{sy} = $sy;
		@$ctgs[$i]->{ex} = $ex;
		@$ctgs[$i]->{ey} = $ey;
		
		# $i%4+1: skip color white
		@{$ctgs}[$i]->{color} = $i%4+1;

		# preload children
		$self->_preload_children( @$ctgs[$i]->{children}, @$ctgs[$i] ) if @$ctgs[$i]->{children};
	}
	
	# right half
	$ey = 0;
	for my $i ( -$#$ctgs .. -$half ) {
		$i = -$i;
		# branch line
		my $sx = sin( $agl * $i + $rotate ) * 50 + $self->xcenter;
		my $sy = cos( $agl * $i + $rotate ) * 50 + $self->ycenter;

		if ( $i != $#$ctgs ) {
			$ey += ( @$ctgs[$i+1]->{height} + @$ctgs[$i]->{height} )/2;
			$ey = $sy+1 if $ey < $sy
		} else {
			$ey = $sy - @$ctgs[$i]->{height}/2;
		}

		my $ex = $sx + 90;
		my $x = abs($ey-$sy)/5;
 		$ex = $sx+$x-3 if $x > 90;

		@$ctgs[$i]->{sx} = $sx;
		@$ctgs[$i]->{sy} = $sy;
		@$ctgs[$i]->{ex} = $ex;
		@$ctgs[$i]->{ey} = $ey;

		# $i%4+1: skip color white
		@{$ctgs}[$i]->{color} = $i%4+1;
	
		# preload children
		$self->_preload_children( @$ctgs[$i]->{children}, @$ctgs[$i] ) if @$ctgs[$i]->{children};
	}

}

sub _preload_children {
	my $self = shift;
	my $ctgs = shift; 
	my $parent = shift;

	# not use same color with parent
	my @color = ();
	for (1..4) {
		push( @color, $_ ) if $_ != $parent->{color};
	}

	my $ey = $parent->{ey} - $parent->{height}/2;
	for my $i ( 0 .. $#$ctgs ) {
		my $sx = $parent->{ex};
		my $sy = $parent->{ey}>$self->ycenter?$parent->{ey}+3:$parent->{ey}-3;
		my $ex = $sx > $self->xcenter() ? $sx + 90 : $sx - 90;
		if ( $i ) {
			$ey += ( @$ctgs[$i-1]->{height} + @$ctgs[$i]->{height}
				- ($#{ @$ctgs[$i]->{entries} }+1)*20 ) /2;
		} else {
			$ey += ( @$ctgs[$i]->{height} ) /2;
		}
		$ey = $sy - 15 if ( $#$ctgs == 0 );

		(@$ctgs[$i]->{sx},@$ctgs[$i]->{sy},@$ctgs[$i]->{ex},@$ctgs[$i]->{ey})
			= ($sx, $sy, $ex, $ey);

		# not use the same color with sibling's last child
		my $sib_child = @{ $parent->{children} }[$i-1]->{children};
		push(@color,shift(@color)) if $i && $sib_child && $color[$i%3] == @$sib_child[$#$sib_child]->{color};

		@$ctgs[$i]->{color} = $color[$i%3];

		# preload children
		$self->_preload_children( @$ctgs[$i]->{children}, @$ctgs[$i] ) if @$ctgs[$i]->{children};
	}

}

sub _get_maxmin {
	my $self = shift;
	my $ctgs = shift;

	my ( $max_w, $min_h, $max_h ) = (0,0,0);
	foreach my $i (@$ctgs) {
		my ( $w, $h1, $h2 );
		if ( $i->{children} ) {
			( $w, $h1, $h2 ) = $self->_get_maxmin( $i->{children} );
		} else {
			$w = max( abs($i->{sx}), abs($i->{ex}) );
			$h1 = min( $i->{sy}, $i->{ey} );
			$h2 = max( $i->{sy}, $i->{ey}+($#{$i->{entries}}+1)*(ENTRY_HEIGHT+4) );
		}

		$max_w = max( $max_w, $w );
		$min_h = min( $min_h, $h1 );
		$max_h = max( $max_h, $h2 );
	}

	return ( $max_w, $min_h, $max_h );
}

sub _calculate_image_size {
	my $self = shift;

	my $half = ceil( ($#{$self->ctgs}+1) / 2 );
	my @left = ();
	push( @left, ${$self->ctgs}[$_] ) for ( 0..$half-1 );
	my ( $lx, $min_ly, $max_ly ) = $self->_get_maxmin( \@left );

	my @right = ();
	push( @right, ${$self->ctgs}[$_] ) for ( $half..$#{$self->ctgs} );
	my ( $rx, $min_ry, $max_ry ) = $self->_get_maxmin( \@right );

	my $edge = 100;
	$self->xlen( $lx + $rx + $edge );
	$self->ylen( max(abs($min_ly),abs($min_ry)) + max($max_ly,$max_ry) + $edge );
	$self->xcenter( $lx + $edge/2 );
	$self->ycenter( max( abs($min_ly), abs($min_ry) ) + $edge/2 );
}

sub _create_image {
	my $self = shift;

	return if ( $self->ctgs == undef );

	_prepare_image_attr( $_ ) for ( @{$self->ctgs} );

	$self->_preload();

	# adjust picture size
	$self->_calculate_image_size();

	my $img   = new GD::Image( $self->xlen, $self->ylen );
	my $color = Mindmap->_init_colors($img);

	$img->transparent( $color->{white} );
	$img->interlaced('true');

	# border
	$img->rectangle( 0, 0, $self->xlen - 1, $self->ylen - 1, $color->{black} );

	# draw contents
	$self->_draw_branch( $img, $self->ctgs ); 

	# center
	$img->arc( $self->xcenter, $self->ycenter, 100 + $_, 100 + $_, 0, 360,
		$color->{brown} ) for ( -4 .. 4 );
	$img->stringFT(
		$color->{brown}, font, 10, 0,
		$self->xcenter - 26,
		$self->ycenter + 4,
		'Mind Map'
	);

	if ( not DEBUG ) {
		my $cfg = $self->plugin->get_config_hash('blog:'.MT->instance->blog->id);
		# version info
		$img->stringFT(	$color->{black}, font, 10, 0, 10, $cfg->{show_blog_name}?22:11,
			'by MovebleType Mindmap ' . $MT::Plugin::Mindmap::VERSION )
				if $cfg->{show_version};

		# blog name
		$img->stringFT(	$color->{black}, font, 10, 0, 10, 11, MT->instance->blog->name )
			if ( $cfg->{show_blog_name} );
	}

	if ( DEBUG ) {
		$self->_save_image( $img, '.' );
	} else {
		$self->_save_image( $img, MT->instance->blog->site_path );
	}
}

sub _draw_branch {
	my $self = shift;
	my $img  = shift;
	my $ctgs = shift;

	for my $i ( 0 .. $#$ctgs ) {
		# draw branch line
		$self->_draw_branch_line( $img, @$ctgs[$i],
			@$ctgs[$i]->{color} );

		# draw children
		$self->_draw_branch( $img, @$ctgs[$i]->{children} ) if @$ctgs[$i]->{children};

		# draw top branch label
		my $text = @$ctgs[$i]->{label};
		my $fs = 10;
		my $sx = @$ctgs[$i]->{ex} + 3;
		# test draw
		my @bounds = $img->stringFT( 0, font, $fs, 0, -100, -100, $text );
		$sx -= ($bounds[2]-$bounds[0]) if @$ctgs[$i]->{ex} > 0;
		$img->stringFT( 5, font, $fs, 0,
			$sx+$self->xcenter, @$ctgs[$i]->{ey}+$self->ycenter-3, $text );
			
		# draw entries
		$self->_draw_entries( $img, @$ctgs[$i] ) if @$ctgs[$i]->{entries};
	}
}

sub _draw_entries {
	my $self = shift;
	my $img = shift;
	my $ctg = shift;

	my $fs = 10;
	my $sy = $ctg->{ey}+$self->ycenter-3;
	for (@{ $ctg->{entries} }) {
		my $text = $_->{title};
		if ( length($text) > 10 ) {
			if ( DEBUG ) {
				$text = substr( $text, 0, 7 );
			} else {
				$text = MT::I18N::ja->substr_text_jcode( $text, 0, 7, 'utf-8' );
			}
			$text .= '...';
		}

		my $sx = $ctg->{ex} + 3 + $self->xcenter;
		$sy += ENTRY_HEIGHT;

		# test draw
		my @bounds = GD::Image->stringFT( 0, font, $fs, 0, 0, 0, $text );
		$sx -= $bounds[2] if $ctg->{ex} > 0;

		# draw a grey background if the entry is DRAFT
		$img->filledRectangle( $sx-2, $sy-12, $sx+$bounds[2]+2, $sy+3, VOILET )
			if $_->{status}==1;

		# title
		@bounds = $img->stringFT( $_->{status}==1?0:BLACK, font, $fs, 0, $sx, $sy, $text );

		# frame
		$img->rectangle( $sx-2, $sy-12, $bounds[2]+2, $sy+3, BLACK );
		
		# save coords
		$_->{coords} = sprintf( "%d,%d,%d,%d", $sx-2, $sy-12, $bounds[2]+2, $sy+3 );
		push( @{$self->entries}, $_ );
	}
}

sub _draw_branch_line {
	my $self = shift;
	my $img   = shift;
	my $ctg = shift;
	my $color = shift;

	my ($sx,$sy,$ex,$ey) = ( $ctg->{sx}+$self->xcenter, $ctg->{sy}+$self->ycenter,
		$ctg->{ex}+$self->xcenter, $ctg->{ey}+$self->ycenter );

	for my $i ( -3 .. 3 ) {
		my $poly = new GD::Polyline;
		$poly->addPt( $sx + $i, $sy );

		my $x = ($ey-$sy)/5;
		$x = -$x if ( ($ex>$sx&&$ey<$sy) || ($ex<$sx&&$ey>$sy) );
		$x += $sx+$i;

		if ( DEBUG ) {
			$img->line( $x-4, $ey, $x+4, $ey, 5 );
			$img->line( $x, $ey-4, $x, $ey+4, 5 );
		}

		$poly->addPt( $x, $ey );

 		if ( $x > $self->xcenter ) {
 			if ( $x < $ex+$i ) {
				$poly->addPt( $ex + $i, $ey );
 			} else {
 				$ctg->{ex} = $x-$self->xcenter;
				$poly->addPt( $x+3, $ey )
 			}
 		} else {
 			if ( $x > $ex+$i ) {
	 			$poly->addPt( $ex + $i, $ey );
 			} else {
 				$ctg->{ex} = $x-$self->xcenter;
				$poly->addPt( $x-3, $ey )
 			}
 		}

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

		black => $im->colorAllocate( 0, 0, 0 ),

		brown  => $im->colorAllocate( 255, 0x99, 0 ),
		violet => $im->colorAllocate( 255, 0,    255 ),
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

1;

use strict;
use GD;
use GD::Polyline;
use Mindmap;

# local unit test for Mindmap.pm

test_get_categories();
#test_create_image();

sub test_get_categories {
	my @cats = (
	{ id => 8, label =>'Header', parent => 0 },
	{ id => 15, label => '読書感想', parent => 0 },
	{ id => 12, label => 'ローマ人の物語', parent => 15 },
	{ id => 14, label => '言語', parent => 0 },
	{ id => 11, label => 'zh-cn', parent => 14},
	{ id => 10, label => '簡体', parent => 11 },
	{ id => 16, label => '繁体', parent => 11 },
	{ id => 13, label => 'en', parent => 14 },
	{ id => 9,  label => 'ja', parent => 14 },
	{ id => 16, label => 'Long English', parent => 0 },
	);

	my %children;
	foreach my $cat (@cats) {
		push @{ $children{ ( $cat->{parent} ) ? $cat->{parent} : '0' } }, $cat;
	}
	foreach my $i ( keys %children ) {
		@{ $children{$i} } =
		  sort { $a->{label} cmp $b->{label} } @{ $children{$i} };
	}

	my @ctgs;
	foreach my $i (@cats) {
		$i->{children} = $children{ $i->{id} };
		push( @ctgs, $i ) if $i->{parent} == 0;
	}
	
	use Data::Dumper;
	print Dumper(\%children);
	print STDERR Dumper(\@ctgs);
}

sub test_create_image {
my $ctgs = [
	{ id => 8, label =>'Header', level => 1 },
	{ id => 15, label => '読書感想', children => [
		{ id => 12, label => 'ローマ人の物語', parent => 15 },
	] },
	{ id => 14, label => '言語', children => [
		{ id => 11, label => 'zh-cn', children => [
			{ id => 10, label => '簡体' },
			{ id => 10, label => '繁体' },
		] },
		{ id => 13, label => 'en' },
		{ id => 9,  label => 'ja'},
	] },
	{ id => 16, label => 'Long English' },
];

my $m = new Mindmap();
$m->maxlvl( 3 );
$m->_create_image($ctgs);
}

1;
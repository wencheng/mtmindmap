use strict;
use GD;
use GD::Polyline;
use Mindmap;
use Data::Dumper;

# local unit test for Mindmap.pm

my $ctgs = [
	{ id => 8, label =>'Header' },
	{ id => 15, label => '読書感想', children => [
		{ id => 12, label => 'ローマ人の物語',
		  entries => [
		  	{ title => '第一卷' },
		  	{ title => '第二卷' }
		  ]
		}
	] },
	{ id => 14, label => '言語', children => [
		{ id => 11, label => 'zh-cn', children => [
			{ id => 10, label => '簡体', children => [
				{ id => 20, label => '1', entries => [
					{ title => '.@/' },
					{ title => 'abc' },
					{ title => 'def' },
					{ title => 'ghi' },
					{ title => 'jkl' },
					{ title => 'mno' },
					{ title => 'pqrs' },
					{ title => 'tuv' },
					{ title => 'wxyz' },
					{ title => '...' },
				] },
				{ id => 20, label => '2' },
				{ id => 20, label => '3' },
				{ id => 20, label => '4' },
				{ id => 20, label => '5' },
				{ id => 20, label => '6' },
				{ id => 20, label => '7' },
				{ id => 20, label => '8' },
				{ id => 20, label => '9' },
				{ id => 20, label => '10' },
				{ id => 20, label => '11' },
			] },
			{ id => 10, label => '繁体',	},
		] },
		{ id => 13, label => 'en' },
		{ id => 9,  label => 'ja',
		  entries => [
		  	{ title => 'あいうえお' },
		  	{ title => 'かきくけこ' },
		  	{ title => 'さしすせそたちつてと' },
		  	{ title => 'なにぬねのはひふへほ' },
		]
		},
		{ id => 9,  label => 'es' },
	] },
	{ id => 16, label => 'Long English', },
];
	
#test_get_categories();
#test_get_deepest_level();
test_create_image();

sub test_create_image {
	my $m = new Mindmap();
	$m->ctgs( $ctgs );
	$m->_create_image();
}

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
	
	print STDERR Dumper(\@ctgs);
}

sub test_get_deepest_level {
	print Dumper( $ctgs );
	print Mindmap::_get_deepest_level( $ctgs, 1 );
}

1;
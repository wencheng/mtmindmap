use strict;
use GD;
use GD::Polyline;
use Mindmap;

# local unit test for Mindmap.pm 

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

1;
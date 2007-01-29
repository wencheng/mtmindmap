package MT::Plugin::Mindmap;
use strict;
use base qw(MT::Plugin);
use MT;
use MT::Template::Context;
use Mindmap;
use vars qw($VERSION);
$VERSION = '0.1';

my $plugin = new MT::Plugin::Mindmap(
	{
		name        => "Mindmap Diagram",
		description =>
		  "<MT_TRANS phrase=\"The Plugin to display category as a mindmap\">",
		doc_link    => "http://wencheng.fang.sh.cn/2007/01/16/182107.shtml",
		plugin_link => "http://code.google.com/p/mtmindmap/",
		author_name => "Wencheng Fang",
		author_link => "http://wencheng.fang.sh.cn/",
		version     => $VERSION,
		blog_config_template => \&configuration_template,
		settings             => new MT::PluginSettings([
			['show_blog_name', {Default=>1}],
			['show_version', {Default=>1}],
			['show_entry', {Default=>1}],
			['font', {Default=>'/usr/share/fonts/truetype/kochi/kochi-mincho.ttf'}],
			# default color goes to red, yellow, blue, green
			['color1_r', {Default=>255}],
			['color1_g', {Default=>80}],
			['color1_b', {Default=>80}],
			['color2_r', {Default=>255}],
			['color2_g', {Default=>220}],
			['color2_b', {Default=>80}],
			['color3_r', {Default=>100}],
			['color3_g', {Default=>100}],
			['color3_b', {Default=>255}],
			['color4_r', {Default=>80}],
			['color4_g', {Default=>255}],
			['color4_b', {Default=>80}],
		]),
		l10n_class           => 'Mindmap::L10N',
	}
);
MT->add_plugin($plugin);
MT->add_plugin_action( 'blog',         'mindmap.cgi', '<MT_TRANS phrase="See mindmap">' );
MT->add_plugin_action( 'entry',        'mindmap.cgi', '<MT_TRANS phrase="See mindmap">' );
MT->add_plugin_action( 'list_entries', 'mindmap.cgi', '<MT_TRANS phrase="See mindmap">' );

MT::Category->add_callback( 'post_save', 11, $plugin, \&cat_post_save_cb );
MT::Entry->add_callback( 'post_save', 11, $plugin, \&entry_post_save_cb );

sub instance { return $plugin; }

sub configuration_template {
	my ( $plugin, $param, $scope ) = @_;

	my $app     = MT->instance;
	my $blog_id = $app->{'blog_id'};

	my $tmpl = <<TMPL;
	<div class="setting">
		<div class="label"><label for="font"><MT_TRANS phrase="Font path:"></label></div>
		<div class="field">
			<input size="50" id="font" name="font" value="<TMPL_VAR NAME=font ESCAPE=HTML>"/>
		</div>
	</div>
	<div class="setting">
		<div class="label"><MT_TRANS phrase="Show entry:"></div>
		<div class="field">
			<p><input type="checkbox" id="show_entry" name="show_entry" value="1"
				<TMPL_IF NAME=show_entry>checked</TMPL_IF>/>
			<label for="show_entry"><MT_TRANS phrase="Show entries of each category in the mindmap<br/>(Only categories would be drawn if not checked)"></label></p>
		</div>
		<div class="label"><MT_TRANS phrase="Show blog name:"></div>
		<div class="field">
			<p><input type="checkbox" id="show_blog_name" name="show_blog_name" value="1"
				<TMPL_IF NAME=show_blog_name>checked</TMPL_IF>/>
			<label for="show_blog_name"><MT_TRANS phrase="Show blog's name in the mindmap"></label></p>
		</div>
		<div class="label"><MT_TRANS phrase="Show version:"></div>
		<div class="field">
			<p><input type="checkbox" id="show_version" name="show_version" value="1"
				<TMPL_IF NAME=show_version>checked</TMPL_IF>/>
			<label for="show_version"><MT_TRANS phrase="Show the version information of this plugin in the mindmap"></label></p>
		</div>
	</div>
	<div class="setting">
		<div class="label"><label for="color1_r"><MT_TRANS phrase="Color1:"></label></div>
		<div class="field">
			<font color="red">R</font><input size="3" maxlength="3" id="color1_r" name="color1_r" value="<TMPL_VAR NAME=color1_r ESCAPE=HTML>"/>
			<font color="green">G</font><input size="3" maxlength="3" name="color1_g" value="<TMPL_VAR NAME=color1_g ESCAPE=HTML>"/>
			<font color="blue">B</font><input size="3" maxlength="3" name="color1_b" value="<TMPL_VAR NAME=color1_b ESCAPE=HTML>"/>
		</div>
		<div class="label"><label for="color2_r"><MT_TRANS phrase="Color2:"></label></div>
		<div class="field">
			<font color="red">R</font><input size="3" maxlength="3" id="color2_r" name="color2_r" value="<TMPL_VAR NAME=color2_r ESCAPE=HTML>"/>
			<font color="green">G</font><input size="3" maxlength="3" name="color2_g" value="<TMPL_VAR NAME=color2_g ESCAPE=HTML>"/>
			<font color="blue">B</font><input size="3" maxlength="3" name="color2_b" value="<TMPL_VAR NAME=color2_b ESCAPE=HTML>"/>
		</div>
		<div class="label"><label for="color3_r"><MT_TRANS phrase="Color3:"></label></div>
		<div class="field">
			<font color="red">R</font><input size="3" maxlength="3" id="color3_r" name="color3_r" value="<TMPL_VAR NAME=color3_r ESCAPE=HTML>"/>
			<font color="green">G</font><input size="3" maxlength="3" name="color3_g" value="<TMPL_VAR NAME=color3_g ESCAPE=HTML>"/>
			<font color="blue">B</font><input size="3" maxlength="3" name="color3_b" value="<TMPL_VAR NAME=color3_b ESCAPE=HTML>"/>
		</div>
		<div class="label"><label for="color4_r"><MT_TRANS phrase="Color4:"></label></div>
		<div class="field">
			<font color="red">R</font><input size="3" maxlength="3" id="color4_r" name="color4_r" value="<TMPL_VAR NAME=color4_r ESCAPE=HTML>"/>
			<font color="green">G</font><input size="3" maxlength="3" name="color4_g" value="<TMPL_VAR NAME=color4_g ESCAPE=HTML>"/>
			<font color="blue">B</font><input size="3" maxlength="3" name="color4_b" value="<TMPL_VAR NAME=color4_b ESCAPE=HTML>"/>
			<p><MT_TRANS phrase="Config the 4 color used in the mindmap."></p>
		</div>
	</div>
	<p></p>
TMPL
}

sub save_config {
    my $plugin = shift;
    my ($param, $scope) = @_;

    my $app = MT->instance;

    return $plugin->SUPER::save_config(@_);
}

sub _rebuild {
	my ($cb, $obj) = @_;
	my $plugin = $cb->{plugin};

	eval {
		my $m = Mindmap->new;
		$m->init;
		$m->build;
	};
	print STDERR $@ if $@;
}

sub cat_post_save_cb {
	_rebuild(@_);
}

sub entry_post_save_cb {
	_rebuild(@_);
}

1;
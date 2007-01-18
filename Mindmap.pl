package MT::Plugin::Mindmap;
use strict;
use base qw(MT::Plugin);
use MT;
use MT::Template::Context;
use vars qw($VERSION);
$VERSION = '0.1';

my $plugin = new MT::Plugin::Mindmap(
	{
		name        => "Mindmap Diagram",
		description =>
		  "<MT_TRANS phrase=\"The Plugin to display category as a mindmap\">",
		doc_link    => "http://wencheng.fang.sh.cn/archives/plugins/helloworld",
		plugin_link => "http://wencheng.fang.sh.cn/archives/plugins/helloworld",
		author_name => "Wencheng Fang",
		author_link => "http://wencheng.fang.sh.cn/",
		version     => $VERSION,
		blog_config_template => \&template,
		settings             => new MT::PluginSettings( [ ['text'] ] ),
		l10n_class           => 'Mindmap::L10N',
	}
);
MT->add_plugin($plugin);
MT->add_plugin_action( 'blog',         'mindmap.cgi', 'See mindmap' );
MT->add_plugin_action( 'entry',        'mindmap.cgi', 'See mindmap' );
MT->add_plugin_action( 'list_entries', 'mindmap.cgi', 'See mindmap' );

sub instance { return $plugin; }

sub template {
	my ( $plugin, $param ) = @_;
	my $app     = MT->instance;
	my $blog_id = $app->{'blog_id'};

	my $text = $param->{text};
	$param->{template_count} = 2;
	my $tmpl = <<TMPL;
	<div class="setting">
		<div class="label"><label for="text">Text:</label></div>
		<div class="field">
			<select name="text">
				<option<TMPL_IF NAME=TEXT_HELLOWORLD> selected="selected"</TMPL_IF>>HelloWorld</option>
				<option<TMPL_IF NAME=TEXT_GOODBYEWORLD> selected="selected"</TMPL_IF>>GoodbyeWorld</option>
			</select>
			<p>HelloWorld can get a bit boring, choose something else to add a little flavour to life</p>
		</div>
	</div>
	<p>There are <TMPL_VAR NAME=TEMPLATE_COUNT> templates called '<TMPL_VAR NAME=TEXT>' in this system</p>
TMPL
}

1;

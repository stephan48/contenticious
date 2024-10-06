package Mojolicious::Plugin::Contenticious;
use Mojo::Base 'Mojolicious::Plugin';

use Contenticious::Content;
use Carp;

has pages_dir   =>  sub {
        croak 'no pages_dir given'
};

has content     =>  sub {
        my $self = shift;

    return Contenticious::Content->new(
                pages_dir   => $self->pages_dir,
    );
};

has config     => sub { {} };

sub register {
        my ($self, $app, $conf) = @_;

        $self->config($conf);

        $self->pages_dir($self->config->{pages_dir} // $app->home->rel_dir('pages'));

        $app->helper(contenticious        => sub { $self->content });
        $app->helper(contenticious_config => sub { $self->config  });

        push @{$app->renderer->classes}, ref($self);

        $app->routes->add_shortcut(
                contenticious => sub {
                        my ($route, $param) = @_;

                        my $serve_content = sub {
                        my $c    = shift;
                        my $path = $c->param('cpath') // '';

                        # delete format
                        $path =~ s/\.html$//;

                        # found matching content node?
                        my $content_node = $c->contenticious->find($path);
                        unless (defined $content_node) {
                            $c->render_not_found;
                            return;
                        }

                        # go
                        $c->render(
                            cpath           => $path,
                            content_node    => $content_node,
                            template        => 'content',
                        );

                        # empty cache?
                        $c->contenticious->empty_cache unless $c->config('cached');
                    };

                    # content routes
                    $route->get('/'         => $serve_content);
                    $route->get('/*cpath'   => $serve_content)->name('content');

                }
        );
}

1;
__DATA__
@@ content.html.ep
% layout 'contenticious', title => $content_node->title;
% if (defined $content_node->html) {
%== render($content_node->html);
% } else {
%= include 'list', content_node => $content_node
% }

@@ list.html.ep
<h1><%= $content_node->title %></h1>
<ul id="content_list">
% foreach my $c (@{$content_node->children}) {
    % my $url = url_for 'content', cpath => $c->path, format => 'html';
    <li><a href="<%= $url %>"><strong><%= $c->title %></strong></a></li>
% }
</ul>

@@ navi.html.ep
% my $node      = contenticious->root_node;
% my @names     = split m|/| => $cpath;
% my $level     = 1;
% LOOP: { do { # perldoc perlsyn: do-while isn't a loop
    % last unless $node->can('children');
    % my $name      = shift(@names) // '';
    % my $id_prefix = 'sub' x ($level - 1);
    % unless (
    %   (defined stash('only') and stash('only') != $level) or
    %   (defined stash('only_not') and stash('only_not') == $level)
    % ) {
    <ul class="navi" id="<%= $id_prefix %>navi">
        % foreach my $c (@{$node->children}) {
            % next if $c->name eq 'index';
            % my $class   = $c->name eq $name ? 'active' : '';
            % my $url = url_for 'content', cpath => $c->path, format => 'html';
        <li class="<%= $class %>">
            <a href="<%= $url %>"><%= $c->navi_name %></a>
        </li>
        % }
    </ul>
    % }
    % $node = $node->find($name) or last;
    % $level++;
% } while 1 }

@@ layouts/contenticious.html.ep
<!doctype html>
<html>
<head>
    % my $t = join ' - ' => grep { $_ } stash('title'), contenticious_config->{'name'};
    <title><%= $t || 'contenticious!' %></title>
    <meta http-equiv="content-type" content="text/html; charset=UTF-8">
    <link rel="stylesheet" type="text/css" href="<%= url_for 'styles.css' %>">
</head>
<body>
<div id="top">
    <div id="inner">
        <p id="name"><a href="<%= url_for 'content', cpath => '' %>">
            <%= contenticious_config->{'name'} // 'contenticious!' %>
        </a></p>
%= include 'navi', only => 1
    </div><!-- inner -->
</div><!-- top -->
<div id="main">
%= include 'navi', only_not => 1
<div id="content">
%= content
</div><!-- content -->
</div><!-- main -->
<div id="footer">
    % if (contenticious_config->{'copyright'}) {
    <p id="copyright">
        &copy;
        <%= 1900 + (localtime)[5] %>
        <%= contenticious_config->{'copyright'} %>
    </p>
    % }
    <p id="built_with">
        built with
        <a href="http://memowe.github.com/contenticious">contenticious</a>,
        on top of <a href="http://mojolicio.us/">Mojolicious</a>.
    </p>
</div><!-- footer -->
</body>
</html>


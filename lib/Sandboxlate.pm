package Sandboxlate;
use 5.012_001;
use strict;
use warnings;

our $VERSION = '0.01';

use Router::Simple::Sinatraish;

use Plack::Builder;
use Plack::Request;
use JSON::XS;
use Text::Xslate;
use Try::Tiny;
use Time::HiRes qw(gettimeofday tv_interval);
use Data::Section::Simple qw/get_data_section/;

my $logfile;
$logfile = '/home/s0710509/log/sandboxlate.log' if -d '/home/s0710509/log';

my $json = JSON::XS->new->pretty->utf8;
my @common_opts = (
    path  => [],
    cache => 0,
);

my %renderers = (
    tterse => Text::Xslate->new( syntax => 'TTerse', @common_opts ),
    kolon  => Text::Xslate->new( syntax => 'Kolon',  @common_opts ),
);
my $supported_renderer_re = do {
    my $re = join( '|', keys %renderers);
    qr/$re/;
};

my $data_section = get_data_section();

sub dispatch_api {
    my($req) = @_;

    my %response;
    try {
        my $syntax = lc($req->param('syntax') || 'Kolon');
        if ($syntax !~ /^$supported_renderer_re$/) {
            die "Syntax $syntax is not supported";
        }

        my $vars = $json->decode($req->param('vars') || '{}');
        my $template = $req->param('template') || '';
        my $renderer = $renderers{ $syntax };

        my $t0     = [gettimeofday()];
        my $result = $renderer->render_string( $template, $vars );
        my $t1     = [gettimeofday()];

        $response{ status }  = 1;
        $response{ message } = "rendered successfully";
        $response{ result }  = $result;
        $response{ time }    = tv_interval($t0, $t1);
    } catch {
        $response{ message } = "An error occurred: $_";
        $response{ status } = 0;
    };

    return [
        200,
        [ "Content-Type" => "application/json" ],
        [ $json->encode( \%response ) ]
    ];
}

sub dispatch_root {
    my ($req) = @_;
    my $html = $data_section->{'index.html'} || die;
    return [200,
        ['Content-Type' => 'text/html;charset=utf-8', 'Content-Length' => length($html)],
        [$html]
    ];
}

sub main {
    my($env) = @_;

    if(defined $logfile and open my $fh, '>>', $logfile) {
        $env->{'psgi.errors'} = $fh;
    }

    my $req = Plack::Request->new($env);
    given($env->{PATH_INFO}) {
        when ('/') {
            return dispatch_root($req);
        }
        when ('/api') {
            return dispatch_api($req);
        }
        default {
            return [404, [], ['not found']];
        }
    }
}

sub to_app {
    builder {
        enable 'Plack::Middleware::Static',
            path => qr{^/static/},
            root => './htdocs/';

        enable 'Plack::Middleware::AccessLog';

        enable 'Plack::Middleware::JSONP';

        \&main;
    };
}

__DATA__

@@ index.html
<!doctype html>
<html>
<head>
    <meta http-equiv="Content-Script-Type" content="text/javascript">
    <script type="text/javascript" src="http://www.google.com/jsapi"></script>
    <script type="text/javascript">google.load("jquery", "1.4.2");</script>
    <script type="text/javascript">
        $(function () {
            $('#TestForm').submit(function () {
                $.ajax({
                    url: './api',
                    data: {
                        template: $('#template').val(),
                        vars: $('#vars').val(),
                        syntax: $('#syntax').val()
                    },
                    success: function (x) {
                        $('#result').text(x);
                    },
                    error: function () {
                        alert("API ERROR");
                    },
                    dataType: 'text'
                });
                return false;
            });
        });
    </script>
</head>
<body>
    <form action="/api" id="TestForm">
        templte:<br />
        <textarea name="template" id="template">Hello, [% thing %]</textarea>
        <br />
        vars(in json):<br />
        <textarea name="vars" id="vars">{"thing":"world"}</textarea>
        <br />
        syntax:<br />
        <select name="syntax" id="syntax">
            <option name="TTerse">TTerse</option>
            <option name="Kolon">Kolon</option>
        </select>
        <br />
        <input type="submit" value="send" />
    </form>
    <hr />
    result:<br />
    <div id="result" style="bordor: solid 1px black"></div>
</body>
</html>


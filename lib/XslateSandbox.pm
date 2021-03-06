package XslateSandbox;
use 5.012_001;
use strict;
use warnings FATAL => 'all';
use utf8;

our $VERSION = '0.01';

use Text::Xslate;

use Plack::Builder;
use Plack::Request;

use Encode qw(decode_utf8 encode_utf8);
use JSON::XS qw(encode_json decode_json);
use Time::HiRes qw(gettimeofday tv_interval);
use Data::Section::Simple qw/get_data_section/;

use BSD::Resource;

use constant {
    MAX_MEMORY => 50 * (2 ** 20), # MiB
    MAX_CPU    => 2,              # sec
};

my $logfile;

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
    my $t0     = [gettimeofday()];

    eval {
        local $SIG{XCPU} = sub {
            die  "TIMEOUT\n";
        };

#        setrlimit(RLIMIT_AS,  MAX_MEMORY, MAX_MEMORY * 2)
#            or die "setrlimit(RLIMIT_AS) failed";

#        setrlimit(RLIMIT_CPU,  MAX_CPU, MAX_CPU * 2)
#            or die "setrlimit(RLIMIT_CPU) failed";

        my $syntax = lc($req->param('syntax') || 'Kolon');
        if ($syntax !~ /^$supported_renderer_re$/) {
            die "Syntax $syntax is not supported";
        }

        my $vars     = decode_json( $req->param('vars')     || '{}' );
        my $template = decode_utf8( $req->param('template') || '' );
        my $renderer = $renderers{ $syntax };

        my $result = $renderer->render_string( $template, $vars );

        $response{ message } = "rendered successfully";
        $response{ result }  = $result;
        $response{ status }  = 1;
    };
    if($@) {
        $@ =~ s/ at \s+ \S+ \s+ line \s+ \d+ //xmsg;
        $response{ message } = "An error occurred: $@";
        $response{ status }  = 0;
    }

    my $t1            = [gettimeofday()];
    $response{ time } = tv_interval($t0, $t1);

    my $content = encode_json(\%response);

    return [
        200,
        [
            "Content-Type" => "application/json",
            "Content-Length" => length($content),
        ],
        [ $content ]
    ];
}

sub dispatch_root {
    my ($req) = @_;
    my $html = $data_section->{'index.html'} || die;
    return [200,
        ['Content-Type' => 'text/html;charset=utf-8',
         'Content-Length' => length($html)],
        [$html]
    ];
}

sub main {
    my($env) = @_;

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
    my($class, $home) = @_;

    builder {
        enable 'Plack::Middleware::Static',
            path => qr{^/static/},
            root => './htdocs/';

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
                        vars:     $('#vars').val(),
                        syntax:   $('#syntax').val()
                    },
                    success: function (x) {
                        $('#result').text(x.result);
                        $('#message').text(x.message);
                        $('#time').text(x.time);
                    },
                    error: function () {
                        $('#result').text("API ERROR");
                    },
                    dataType: 'json'
                });
                return false;
            });
        });
    </script>
</head>
<body>
    <form action="/api" id="TestForm">
    <p>
        templte:<br />
        <textarea name="template" id="template" cols="80">Hello, <: $lang :> world!</textarea>
        <br />
        vars (in JSON):<br />
        <textarea name="vars" id="vars" cols="80">{"lang":"Xslate"}</textarea>
        <br />
        <br />
        syntax:
        <select name="syntax" id="syntax">
            <option name="Kolon">Kolon</option>
            <option name="TTerse">TTerse</option>
        </select>
        <input type="submit" value="send" />
    </form>
    <hr />

    result:
    <div id="result" style="bordor: solid 1px black; white-space: pre"></div>
    <br />

    message:
    <div id="message" style="bordor: solid 1px black; white-space: pre"></div>
    <br />

    time:
    <div id="time" style="bordor: solid 1px black; white-space: pre"></div>
    <br />
    <hr />

    <address><a href="http://xslate.org">xslate.org</a></address>
</body>
</html>


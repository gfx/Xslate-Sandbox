#!psgi
# Parameters: syntax="TTerse"|"Kolon", template=$src, vars=\%vars
package Sandboxlate;
use 5.008_001;
our $VERSION = '0.01';

use strict;
use warnings;

use Plack::Builder;
use Plack::Request;
use JSON::XS;
use Text::Xslate;
use Try::Tiny;
use Time::HiRes qw(gettimeofday tv_interval);

my $json = JSON::XS->new->pretty->utf8;
my %renderers = (
    tterse => Text::Xslate->new( syntax => 'TTerse' ),
    kolon  => Text::Xslate->new( syntax => 'Kolon' ),
);
my $supported_renderer_re = do {
    my $re = join( '|', keys %renderers);
    qr/$re/;
};

sub main {
    my($env) = @_;

    my %response;
    try {
        my $req = Plack::Request->new($env);
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

builder {
    enable 'Plack::Middleware::Static',
        path => qr{^/static/},
        root => './htdocs/';

    \&main;
};


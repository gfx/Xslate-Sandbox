#!perl -w
use strict;
use Test::More;

use Plack::Test;
use Plack::Util;
use HTTP::Request;
use JSON::XS qw(decode_json encode_json);
use Text::Xslate qw(uri_escape);

my $app = Plack::Util::load_psgi('xslate.psgi');

my @set = (
    ['Hello, <: $lang :> world!', { lang => 'Xslate' }, 'Hello, Xslate world!'],
    ['Hello, <: $lang :> world!', { lang => 'Xslate' }, 'Hello, Xslate world!', 'Kolon'],
    ['Hello, [%  lang %] world!', { lang => 'Xslate' }, 'Hello, Xslate world!', 'TTerse'],
);

test_psgi
    app    => $app,
    client => sub {
        my $cb = shift;

        foreach my $d(@set) {
            my($in, $vars, $expect, $syntax) = @$d;
            my $req = HTTP::Request->new(
                GET => "http://localhost/hello?"
                    . "template=" . uri_escape($in) . ";"
                    . "vars=" . uri_escape(encode_json($vars)) . ";"
                    . "syntax=" . ($syntax || '') . ";"
            );
            my $res = $cb->($req);
            ok $res->is_success, 'is_success';

            my $content = decode_json($res->content);
            ok $content->{status}, $content->{message};
            is $content->{result}, $expect;
            cmp_ok $content->{time}, '>', 0;
        }
    },
;

done_testing;

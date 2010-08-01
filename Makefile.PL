#!perl -w
use strict;
use inc::Module::Install;

all_from 'xslate.psgi';

requires 'Text::Xslate' => 0.1052;
requires 'Plack'        => 0.9943;
requires 'JSON::XS';
requires 'Try::Tiny';
requires 'Time::HiRes';

tests_recursive;

WriteAll( check_nmake => 0 );

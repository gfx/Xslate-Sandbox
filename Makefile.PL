#!perl -w
use strict;
use inc::Module::Install;

all_from 'lib/XslateSandbox.pm';

requires 'Text::Xslate' => 0.2013;
requires 'Plack'        => 0.9943;
requires 'JSON::XS';
requires 'Time::HiRes';
requires 'BSD::Resource';

tests_recursive;

WriteAll( check_nmake => 0 );

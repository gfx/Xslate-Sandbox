#!perl
# Parameters: syntax="TTerse"|"Kolon", template=$src, vars=\%vars
use strict;
use File::Basename qw(dirname);
use lib dirname(__FILE__) . '/lib';
use lib::xi;

use XslateSandbox;

use Plack::Builder;

builder {
    enable 'Plack::Middleware::AccessLog';

    XslateSandbox->to_app();
};


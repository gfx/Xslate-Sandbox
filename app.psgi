#!perl
# Parameters: syntax="TTerse"|"Kolon", template=$src, vars=\%vars
use strict;
use XslateSandbox;

use Plack::Builder;

builder {
    enable 'Plack::Middleware::AccessLog';

    XslateSandbox->to_app();
};


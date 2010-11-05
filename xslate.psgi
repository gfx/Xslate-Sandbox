#!perl
# Parameters: syntax="TTerse"|"Kolon", template=$src, vars=\%vars
use strict;
use XslateSandbox;
use File::Basename qw(dirname);
XslateSandbox->to_app(dirname __FILE__);

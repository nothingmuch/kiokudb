#!/usr/bin/perl

use strict;
use warnings;

use Test::More no_plan => 1;
use Test::Exception;

BEGIN {
    use_ok('MooseX::Storage::Directory');
    use_ok('MooseX::Storage::Directory::WithUUID');
}

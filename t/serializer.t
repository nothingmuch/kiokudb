#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use ok 'KiokuDB::Serializer';
use ok 'KiokuDB::Serializer::JSON';
use ok 'KiokuDB::Serializer::Storable';
use ok 'KiokuDB::Serializer::YAML';

{
    my $s = KiokuDB::Serializer::Storable->new;

}


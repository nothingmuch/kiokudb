#!/usr/bin/perl

use Test::More 'no_plan';

use ok 'KiokuDB';
use ok 'KiokuDB::Backend::Hash';

use KiokuDB::Test;

run_all_fixtures( KiokuDB->connect("hash") );


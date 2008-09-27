#!/usr/bin/perl

use Test::More 'no_plan';
use Test::TempDir;

use ok 'KiokuDB';
use ok 'KiokuDB::Backend::JSPON';

use KiokuDB::Test;

run_all_fixtures( KiokuDB->connect("jspon:dir=" . temp_root) );


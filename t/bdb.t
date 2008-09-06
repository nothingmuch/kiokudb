#!/usr/bin/perl

use Test::More 'no_plan';
use Test::TempDir;

use ok 'KiokuDB';
use ok 'KiokuDB::Backend::BDB';

use KiokuDB::Test;

run_all_fixtures(
    KiokuDB->new(
        backend => KiokuDB::Backend::BDB->new(
            dir => temp_root,
        ),
    )
);


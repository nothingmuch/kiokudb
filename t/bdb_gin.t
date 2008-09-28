#!/usr/bin/perl

use Test::More 'no_plan';
use Test::TempDir;

use ok 'KiokuDB';
use ok 'KiokuDB::Backend::BDB::GIN';

use ok 'Search::GIN::Extract::Class';

use KiokuDB::Test;

run_all_fixtures(
    KiokuDB->new(
        backend => KiokuDB::Backend::BDB::GIN->new(
            extract => Search::GIN::Extract::Class->new,
            root_only => 0,
            manager => {
                home => temp_root,
                create => 1,
            },
        ),
    )
);


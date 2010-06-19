#!/usr/bin/perl

use Test::More;

use ok 'KiokuDB';
use ok 'KiokuDB::Backend::Hash';

use KiokuDB::Test;

foreach my $format ( qw(memory storable json), eval { require YAML::XS; "yaml" } ) {
    foreach my $keep_entries ( 1, 0 ) {
        foreach my $queue ( 1, 0 ) {
            run_all_fixtures(
                KiokuDB->connect(
                    "hash",
                    serializer => $format,
                    linker_queue => $queue,
                    live_objects => { keep_entries => $keep_entries },
                ),
            );
        }
    }
}


done_testing;

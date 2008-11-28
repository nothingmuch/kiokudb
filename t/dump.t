#!/usr/bin/perl

use strict;
use warnings;

use Scalar::Util qw(refaddr);

use Test::More 'no_plan';

use ok 'KiokuDB::Cmd::Command::Dump';
use ok 'KiokuDB::Cmd::Command::Load';

use ok 'KiokuDB::Backend::Hash';
use ok 'KiokuDB';

use ok 'KiokuDB::Test::Fixture::ObjectGraph';

my @formats = qw(storable);

push @formats, "yaml" if eval { require YAML::XS };

foreach my $format ( @formats ) {
    my $backend = KiokuDB::Backend::Hash->new;

    my $dir = KiokuDB->new( backend => $backend );

    my $s = $dir->new_scope;

    my $f = KiokuDB::Test::Fixture::ObjectGraph->new( directory => $dir );

    $f->populate;

    my @ids = ( $f->homer, $f->dubya, $f->putin );

    my @objs = $dir->lookup(@ids);

    isa_ok( $_, "KiokuDB::Test::Person" ) for @objs;

    my $buf = '';

    open my $fh, ">", \$buf;;

    my $dump = KiokuDB::Cmd::Command::Dump->new(
        backend => $backend,
        output_handle => $fh,
        format => $format,
    );

    isa_ok( $dump, "KiokuDB::Cmd::Command::Dump", "$format dumper" );

    is( $buf, "", "nothing in buffer" );

    $dump->run;

    isnt( $buf, "", "buffer full" );

    cmp_ok( length($buf), '>', 0, "buf has a nonzero length" );


    {
        my $copy_backend = KiokuDB::Backend::Hash->new;
        my $copy = KiokuDB->new( backend => $copy_backend );

        my $scope = $copy->new_scope;

        open my $read, "<", \$buf;

        my $load = KiokuDB::Cmd::Command::Load->new(
            backend => $copy_backend,
            input_handle => $read,
            format => $format,
        );

        isa_ok( $load, "KiokuDB::Cmd::Command::Load", "$format loader" );

        is_deeply(
            [ $copy_backend->all_entries->all ],
            [],
            "no entries in copy backend",
        );

        is_deeply(
            [ $copy->lookup(@ids) ],
            [ ],
            "lookup fails",
        );

        $load->run;

        foreach my $ent ( "all_entries", "root_entries" ) {
            is_deeply(
                [ sort { $a->id cmp $b->id } $copy_backend->$ent->all ],
                [ sort { $a->id cmp $b->id } $backend->$ent->all ],
                "$ent set equals",
            );
        }

        my @copy_objs = $copy->lookup(@ids);

        is_deeply(
            \@copy_objs,
            \@objs,
            "objects eq deeply",
        );

        isnt( refaddr($objs[0]), refaddr($objs[1]), "refaddrs differ between two dirs" );
    }
}


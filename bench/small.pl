#!/usr/bin/perl

use strict;
use warnings;

use KiokuDB;
use KiokuDB::Backend::Hash;

#use Data::Structure::Util qw(circular_off);
sub circular_off {}

$| = 1;

my $f = (require KiokuDB::Test::Fixture::Small)->new;

my $mxsd_hash = KiokuDB->new(
    backend => KiokuDB::Backend::Hash->new,
);

sub bench_write {
    for ( 1 .. 20 ) {
        my $t = times;
        until ( times() - $t > 1 ) {
            for ( 1 .. 10 ) {
                my @objs = $f->create, $f->create;
                $mxsd_hash->store(@objs);
                circular_off(\@objs);
            }
        }
        $mxsd_hash->backend->clear;
        print ".";
        print " " if $_ % 5 == 0;
    }

    print "done\n";
}

sub bench_read {
    my @ids = $mxsd_hash->store($f->create, $f->create);

    for ( 1 .. 20 ) {
        my $t = times;
        until ( times() - $t > 1 ) {
            for ( 1 .. 250 ) { 
                circular_off($mxsd_hash->lookup(@ids));
            }
        }
        print ".";
        print " " if $_ % 5 == 0;
    }

    print "done\n";
}

#bench_read();
bench_write();

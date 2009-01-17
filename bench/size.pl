#!/usr/bin/perl

use strict;
use warnings;

use Test::TempDir;
use Path::Class;
use Storable qw(nstore retrieve);
use Scalar::Util qw(blessed);

use KiokuDB;

my $f = (require KiokuDB::Test::Fixture::ObjectGraph)->new;

sub construct {
    $f->create;
}

sub run {
    my $dir = dir(tempdir);

    #my $files = KiokuDB->connect("files:dir=" . $dir->subdir("files"), create => 1, global_lock => 1 );
    my $bdb = KiokuDB->connect("bdb:dir=" . $dir->subdir("bdb"), create => 1 );
    #my $sqlite = KiokuDB->connect("dbi:SQLite:dbname=" . $dir->file("sqlite.db"), serializer => "storable" );

    #$sqlite->backend->dbh->do("PRAGMA default_synchronous = OFF");

    #$sqlite->backend->deploy;

    for ( my $i = 1; 1; $i++ ) {
        foreach my $b ( $bdb ) {
            $b->txn_do(sub {
                my $s = $b->new_scope;
                $b->insert(construct()) for 1 .. 20;
            });
        }

        warn "iteration $i\n";
        system("du -sh ${dir}/bdb/objects ${dir}/*");
    }
}

run();

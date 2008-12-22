#!/usr/bin/perl

use strict;
use warnings;

use Test::TempDir;
use Path::Class;
use Storable qw(nstore retrieve);
use Scalar::Util qw(blessed);

use KiokuDB;
use KiokuDB::Backend::Hash;
use KiokuDB::Backend::JSPON;
use KiokuDB::Backend::BDB;
#use KiokuDB::Backend::CouchDB;

# no long running tests
my $large = 0;

use Benchmark qw(cmpthese);

my $f = (require KiokuDB::Test::Fixture::ObjectGraph)->new;

sub construct {
    $f->create;
}

sub bench {
    my $dir = dir(tempdir);

    my $storable = $dir->file("foo.storable")->stringify;

    my $mxsd_hash = KiokuDB->new(
        backend => KiokuDB::Backend::Hash->new,
    );

    my $mxsd_jspon = KiokuDB->new(
        backend => KiokuDB::Backend::JSPON->new(
            dir  => $dir->subdir("mxsd_jspon"),
            lock => 0,
        ),
    );

    my $mxsd_bdb_txn = KiokuDB->new(
        backend => KiokuDB::Backend::BDB->new(
            manager => { home => $dir->subdir("mxsd_bdb_txn"), create => 1 }
        ),
    );

    my $mxsd_sqlite = KiokuDB->connect("dbi:SQLite:dbname=" . $dir->file("sqlite.db") );

    $mxsd_sqlite->backend->dbh->do("PRAGMA default_synchronous = OFF");

    $mxsd_sqlite->backend->deploy;

    my $mxsd_mysql = KiokuDB->connect("dbi:mysql:test");

    $mxsd_mysql->backend->deploy({ add_drop_table => 1, producer_args => { mysql_version => 5 } });

    my $mxsd_pg = KiokuDB->connect("dbi:Pg:dbname=test", user => "postgres", password => "290685kj");

    $mxsd_pg->backend->deploy({ add_drop_table => 1 });

    $dir->subdir("mxsd_bdb_dumb")->mkpath;
    my $mxsd_bdb_dumb = KiokuDB->new(
        backend => KiokuDB::Backend::BDB->new(
            manager => {
                home => $dir->subdir("mxsd_bdb_dumb"),
                transactions => 0,
                create => 1,
            },
        ),
    );

    my $mxsd_couch;

    if ( my $uri = $ENV{KIOKU_COUCHDB_URI} ) {
        require KiokuDB::Backend::CouchDB;
        require Net::CouchDB;

        my $couch = Net::CouchDB->new($uri);

        my $name = $ENV{KIOKU_COUCHDB_NAME} || "kioku-$$";

        eval { $couch->db($name)->delete };

        my $db = $couch->create_db($name);

        $mxsd_couch = KiokuDB->new(
            backend => KiokuDB::Backend::CouchDB->new(
                db => $db,
            ),
        );

        $mxsd_couch->{__guard} = Scope::Guard->new(sub { $db->delete });
    }

    warn "\nwriting...\n";

    $mxsd_bdb_txn->backend->txn_do(sub {

        cmpthese(-3, {
            #null         => sub { my @objs = construct(); },
            mxsd_hash    => sub { my @objs = construct(); my $s = $mxsd_hash->new_scope; $mxsd_hash->store(grep { blessed($_) } @objs) },
            mxsd_jspon   => sub { my @objs = construct(); my $s = $mxsd_jspon->new_scope; $mxsd_jspon->store(grep { blessed($_) } @objs) },
            mxsd_bdb     => sub { my @objs = construct(); my $s = $mxsd_bdb_dumb->new_scope; $mxsd_bdb_dumb->store(grep { blessed($_) } @objs) },
            mxsd_bdb_txn => sub { my @objs = construct(); my $s = $mxsd_bdb_txn->new_scope; $mxsd_bdb_txn->store(grep { blessed($_) } @objs) },
            mxsd_sqlite  => sub { my @objs = construct(); my $s = $mxsd_sqlite->new_scope; $mxsd_sqlite->store(grep { blessed($_) } @objs) },
            mxsd_mysql   => sub { my @objs = construct(); my $s = $mxsd_mysql->new_scope; $mxsd_mysql->store(grep { blessed($_) } @objs) },
            mxsd_pg      => sub { my @objs = construct(); my $s = $mxsd_pg->new_scope; $mxsd_pg->store(grep { blessed($_) } @objs) },
            ( $mxsd_couch ? ( mxsd_couch => sub { my @objs = construct(); my $s = $mxsd_couch->new_scope; $mxsd_couch->store(grep { blessed($_) } @objs) } ) : () ),
            storable   => sub { nstore([ construct() ], $storable) },
        });

    });

    warn "\nreading...\n";

    nstore([ construct() ], $storable);
    my @hash_ids  = do { my @objs = construct(); my $s = $mxsd_hash->new_scope; $mxsd_hash->store(grep { blessed($_) } @objs) };
    my @jspon_ids = do { my @objs = construct(); my $s = $mxsd_jspon->new_scope; $mxsd_jspon->store(grep { blessed($_) } @objs) };
    my @bdb_d_ids = do { my @objs = construct(); my $s = $mxsd_bdb_dumb->new_scope; $mxsd_bdb_dumb->store(grep { blessed($_) } @objs) };
    my @bdb_t_ids = do { my @objs = construct(); my $s = $mxsd_bdb_txn->new_scope; $mxsd_bdb_txn->backend->txn_do(sub { $mxsd_bdb_txn->store(grep { blessed($_) } @objs) }); };
    my @sqlite_t_ids = do { my @objs = construct(); my $s = $mxsd_sqlite->new_scope; $mxsd_sqlite->backend->txn_do(sub { $mxsd_sqlite->store(grep { blessed($_) } @objs) }); };
    my @mysql_t_ids = do { my @objs = construct(); my $s = $mxsd_mysql->new_scope; $mxsd_mysql->backend->txn_do(sub { $mxsd_mysql->store(grep { blessed($_) } @objs) }); };
    my @pg_t_ids = do { my @objs = construct(); my $s = $mxsd_pg->new_scope; $mxsd_pg->backend->txn_do(sub { $mxsd_pg->store(grep { blessed($_) } @objs) }); };
    my @couch_ids = $mxsd_couch ? do { my @objs = construct(); my $s = $mxsd_couch->new_scope; $mxsd_couch->store(grep { blessed($_) } @objs) } : ();

    cmpthese(-3, {
        storable     => sub { my $objs = retrieve($storable) },
        mxsd_hash    => sub { my $s = $mxsd_hash->new_scope; my @objs = $mxsd_hash->lookup(@hash_ids) },
        mxsd_jspon   => sub { my $s = $mxsd_jspon->new_scope; my @objs = $mxsd_jspon->lookup(@jspon_ids) },
        mxsd_bdb     => sub { my $s = $mxsd_bdb_dumb->new_scope; my @objs = $mxsd_bdb_dumb->lookup(@bdb_d_ids) },
        mxsd_bdb_txn => sub { my $s = $mxsd_bdb_txn->new_scope; my @objs = $mxsd_bdb_txn->lookup(@bdb_t_ids) },
        mxsd_sqlite  => sub { my $s = $mxsd_sqlite->new_scope; my @objs = $mxsd_sqlite->lookup(@sqlite_t_ids) },
        mxsd_mysql   => sub { my $s = $mxsd_mysql->new_scope; my @objs = $mxsd_mysql->lookup(@mysql_t_ids) },
        mxsd_pg      => sub { my $s = $mxsd_pg->new_scope; my @objs = $mxsd_pg->lookup(@pg_t_ids) },
        ( $mxsd_couch ? ( mxsd_couch => sub { my $s = $mxsd_couch->new_scope; my @objs = $mxsd_couch->lookup(@couch_ids) } ) : () ),
    });
}

bench();


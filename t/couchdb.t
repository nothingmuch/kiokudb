#!/usr/bin/perl

use Test::More;

BEGIN {
    plan skip_all => 'Please set NET_COUCHDB_URI to a CouchDB instance URI' unless $ENV{TEST_COUCHDB_URI};
    plan 'no_plan';
}

#BEGIN { $MooseX::Storage::Directory::SERIAL_IDS = 1 }

use ok 'MooseX::Storage::Directory';
use ok 'MooseX::Storage::Directory::Backend::CouchDB';

use Net::CouchDB;

my $couch = Net::CouchDB->new($ENV{TEST_COUCHDB_URI});

eval { $couch->db("mxsd")->delete };

my $db = $couch->create_db("mxsd");

my $dir = MooseX::Storage::Directory->new(
    backend => MooseX::Storage::Directory::Backend::CouchDB->new(
        db => $db,
    ),
    #backend => MooseX::Storage::Directory::Backend::JSPON->new(
    #    dir    => temp_root,
    #    pretty => 1,
    #    lock   => 0,
    #),
);

use ok 'MooseX::Storage::Directory::Test::Fixture::Person';

my $f = MooseX::Storage::Directory::Test::Fixture::Person->new( directory => $dir );

$f->populate;

$f->verify;


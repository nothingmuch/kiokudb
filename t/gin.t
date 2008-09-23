#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use KiokuDB::Test;

use Scalar::Util qw(refaddr);

use ok 'KiokuDB::GIN';
use ok 'KiokuDB';

use ok 'KiokuDB::Backend::Hash';
use ok 'KiokuDB::Test::Fixture::Small';

use ok 'Search::GIN::Query::Class';
use ok 'Search::GIN::Extract::Class';

{
    package MyGIN;
    use Moose;

    extends qw(KiokuDB::Backend::Hash);

    with (
        qw(
            KiokuDB::GIN
            Search::GIN::Driver::Hash
            Search::GIN::Extract::Delegate
        ),
    );

    __PACKAGE__->meta->make_immutable;
}

my $gin = MyGIN->new(
    extract => Search::GIN::Extract::Class->new,
    root_only => 0,
);

my $dir = KiokuDB->new(
    backend => $gin,
);

run_all_fixtures($dir);


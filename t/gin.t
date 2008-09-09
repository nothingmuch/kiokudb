#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Moose;

use ok 'KiokuDB::GIN';

use ok 'KiokuDB';

use ok 'KiokuDB::Backend::Hash';
use ok 'KiokuDB::Test::Fixture::Small';

use ok 'Search::GIN::Query::Class';
use ok 'Search::GIN::Extract::Class';

{
    package MyGIN;
    use Moose;

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
    backend => KiokuDB::Backend::Hash->new,
    extract => Search::GIN::Extract::Class->new,
    root_only => 0,
);

my $dir = KiokuDB->new(
    backend => $gin,
);

my $f = KiokuDB::Test::Fixture::Small->new;

my @objs = $f->create;

$dir->store(@objs);

my $q_person = Search::GIN::Query::Class->new( class => "KiokuDB::Test::Person" );
my $q_employee = Search::GIN::Query::Class->new( class => "KiokuDB::Test::Employee" );

my $people = $dir->search($q_person);
my $employees = $dir->search($q_employee);

does_ok($_, "Data::Stream::Bulk") for ( $people, $employees );

my @people = $people->all;
my @employees = $employees->all;

is_deeply(
    \@employees,
    [ $objs[0] ],
    "employees",
);

is_deeply(
    [ sort @people ],
    [ sort @objs, @{ $objs[0]->parents } ],
    "set of all people",
);


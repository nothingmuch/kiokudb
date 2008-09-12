#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Moose;
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

{
    my $f = KiokuDB::Test::Fixture::Small->new;

    my $q_person = Search::GIN::Query::Class->new( class => "KiokuDB::Test::Person" );
    my $q_employee = Search::GIN::Query::Class->new( class => "KiokuDB::Test::Employee" );

    {
        my $s = $dir->new_scope;

        my @objs = $f->create;

        $dir->store(@objs);

        my $people = $dir->search($q_person);
        my $employees = $dir->search($q_employee);

        does_ok($_, "Data::Stream::Bulk") for ( $people, $employees );

        my @people = $people->all;
        my @employees = $employees->all;

        is_deeply(
            [ sort map { refaddr($_) } @employees ],
            [ refaddr($objs[0]) ],
            "employees",
        );

        is_deeply(
            [ sort map { refaddr($_) } @people ],
            [ sort map { refaddr($_) } @objs, @{ $objs[0]->parents } ],
            "set of all people",
        );
    }

    is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

    {
        my $s = $dir->new_scope;

        my ( $joe, $mum, $oscar ) = sort { $a->name cmp $b->name } $dir->search($q_person)->all;

        is( $joe->name, "joe", "loaded first object" );
        is( $mum->name, "mum", "loaded second object" );
        is( $oscar->name, "oscar", "loaded third object" );

        is( $joe->parents->[0], $mum, "interrelated objects loaded in one graph" );
    }
}

# lastly make sure we pass sanity
run_all_fixtures($dir);


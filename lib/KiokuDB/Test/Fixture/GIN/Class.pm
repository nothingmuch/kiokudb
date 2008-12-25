#!/usr/bin/perl

package KiokuDB::Test::Fixture::GIN::Class;
use Moose;

use Test::More;
use Test::Moose;
use Scalar::Util qw(refaddr);

use Search::GIN::Query::Class;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Test::Fixture::Small);

use constant required_backend_roles => qw(Clear Scan Query::GIN);

before populate => sub {
    my $self = shift;
    $self->backend->clear;
};

sub verify {
    my $self = shift;

    my $q_person = Search::GIN::Query::Class->new( class => "KiokuDB::Test::Person" );
    my $q_employee = Search::GIN::Query::Class->new( class => "KiokuDB::Test::Employee" );
    my $q_both = Search::GIN::Query::Class->new( class => "KiokuDB::Test::Person", blessed => "KiokuDB::Test::Employee" );

    {
        my $s = $self->new_scope;

        my @objs = $self->root_set->all;

        my $people = $self->search($q_person);
        my $employees = $self->search($q_employee);

        does_ok($_, "Data::Stream::Bulk") for ( $people, $employees );

        my @people    = $people->all;
        my @employees = $employees->all;

        is_deeply(
            [ sort map { refaddr($_) } @employees ],
            [ refaddr($self->lookup_ok($self->joe)) ],
            "employees",
        );

        is_deeply(
            [ sort map { refaddr($_) } @people ],
            [ sort map { refaddr($_) } @objs, @{ $self->lookup_ok($self->joe)->parents } ],
            "set of all people",
        );
    }

    $self->no_live_objects;

    {
        my $s = $self->new_scope;

        my ( $joe, $mum, $oscar ) = sort { $a->name cmp $b->name } $self->search($q_person)->all;

        is( $joe->name, "joe", "loaded first object" );
        is( $mum->name, "mum", "loaded second object" );
        is( $oscar->name, "oscar", "loaded third object" );

        is( $joe->parents->[0], $mum, "interrelated objects loaded in one graph" );
    }

    $self->no_live_objects;

    {
        my $s = $self->new_scope;

        my $employees = $self->search($q_both);

        does_ok($employees, "Data::Stream::Bulk");

        my @employees = $employees->all;

        is_deeply(
            [ sort map { refaddr($_) } @employees ],
            [ refaddr($self->lookup_ok($self->joe)) ],
            "employees",
        );
    }

    $self->no_live_objects;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

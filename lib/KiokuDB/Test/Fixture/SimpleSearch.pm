#!/usr/bin/perl

package KiokuDB::Test::Fixture::SimpleSearch;
use Moose;

use Test::More;
use Test::Moose;

use KiokuDB::Test::Person;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Test::Fixture) => { excludes => 'required_backend_roles' };

use constant required_backend_roles => qw(Clear Query::Simple);

sub create {
    my $self = shift;

    ( map { KiokuDB::Test::Person->new(%$_) }
        { name => "foo", age => 3 },
        { name => "bar", age => 3 },
        { name => "gorch", age => 5, friends => [ KiokuDB::Test::Person->new( name => "quxx", age => 6 ) ] },
    );
}

before populate => sub {
    my $self = shift;
    $self->backend->clear;
};

sub verify {
    my $self = shift;

    {
        my $s = $self->new_scope;

        my $res = $self->search({ name => "foo" });

        does_ok( $res, "Data::Stream::Bulk" );

        my @objs = $res->all;

        is( @objs, 1, "one object" );

        is( $objs[0]->name, "foo", "name attr" );
    }

    $self->no_live_objects;

    {
        my $s = $self->new_scope;

        my $res = $self->search({ age => 3 });

        does_ok( $res, "Data::Stream::Bulk" );

        my @objs = $res->all;

        is( @objs, 2, "two objects" );

        @objs = sort { $a->name cmp $b->name } @objs;

        is( $objs[0]->name, "bar", "name attr" );
        is( $objs[1]->name, "foo", "name attr" );
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__


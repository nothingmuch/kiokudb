#!/usr/bin/perl

package KiokuDB::Test::Fixture::Overwrite;
use Moose;

use Test::More;
use Test::Exception;

use KiokuDB::Test::Person;
use KiokuDB::Test::Employee;
use KiokuDB::Test::Company;

sub p {
    my @args = @_;
    unshift @args, "name" if @args % 2;
    KiokuDB::Test::Person->new(@args);
}

with qw(KiokuDB::Test::Fixture);

sub sort { -100 }

sub create {
    return (
        KiokuDB::Test::Person->new(
            name    => "blah",
        ),
    );
}

sub populate {
    my $self = shift;

    {
        my $s = $self->new_scope;

        my ( $p ) = $self->create;

        isa_ok( $p, "KiokuDB::Test::Person" );

        $self->store_ok( person => $p );

        $self->live_objects_are($p);
    }

    $self->no_live_objects;
}

sub verify {
    my $self = shift;

    {
        my $s = $self->new_scope;

        my $p = $self->lookup_ok("person");

        isa_ok( $p, "KiokuDB::Test::Person" );

        is( $p->name, "blah", "name attr" );

        $p->name("new name");

        lives_ok {
            $self->directory->store($p);
        } "update";
    }

    $self->no_live_objects;

    dies_ok {
        $self->directory->store( person => KiokuDB::Test::Person->new( name => "duplicate" ) );
    } "can't insert duplicate";
}

__PACKAGE__

__END__


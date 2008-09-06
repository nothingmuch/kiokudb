#!/usr/bin/perl

package KiokuDB::Test::Fixture::Small;
use Moose;

use Test::More;

use KiokuDB::Test::Person;
use KiokuDB::Test::Employee;
use KiokuDB::Test::Company;

sub p {
    my @args = @_;
    unshift @args, "name" if @args % 2;
    KiokuDB::Test::Person->new(@args);
}

use Data::Structure::Util qw(circular_off);

with qw(KiokuDB::Test::Fixture);

sub sort { -100 }

has person => (
    isa => "Str",
    is  => "rw",
);

sub create {
    return KiokuDB::Test::Employee->new(
        name    => "joe",
        age     => 52,
        parents => [ KiokuDB::Test::Person->new(
            name => "mum",
            age  => 78,
        ) ],
        company => KiokuDB::Test::Company->new(
            name => "OHSOME SOFTWARE KTHX"
        ),
    );
}

sub populate {
    my $self = shift;

    my $person = $self->create;

    isa_ok( $person, "KiokuDB::Test::Person" );

    my $id = $self->store_ok($person);

    $self->person($id);

    $self->live_objects_are($person, $person->company, @{ $person->parents });

    undef $person;

    $self->no_live_objects;
}

sub verify {
    my $self = shift;

    my $person = $self->lookup_ok( $self->person );

    isa_ok( $person, "KiokuDB::Test::Person" );
    isa_ok( $person, "KiokuDB::Test::Employee" );

    is( $person->name, "joe", "name" );

    ok( my $parents = $person->parents, "parents" );

    is( ref($parents), "ARRAY", "array ref" );
    
    is( scalar(@$parents), 1, "one parent" );

    isa_ok( $parents->[0], "KiokuDB::Test::Person" );

    is( $parents->[0]->name, "mum", "parent name" );

    ok( my $company = $person->company, "company" );

    isa_ok( $company, "KiokuDB::Test::Company" );
}
__PACKAGE__

__END__

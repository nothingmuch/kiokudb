#!/usr/bin/perl

package KiokuDB::Test::Fixture::Small;
use Moose;

use Test::More;
use Test::Exception;

use Scalar::Util qw(refaddr);

use KiokuDB::Test::Person;
use KiokuDB::Test::Employee;
use KiokuDB::Test::Company;

sub p;

use namespace::clean -except => 'meta';

sub p {
    my @args = @_;
    unshift @args, "name" if @args % 2;
    KiokuDB::Test::Person->new(@args);
}

with qw(KiokuDB::Test::Fixture) => { -excludes => [qw/populate sort/] };

sub sort { -100 }

has [qw(joe oscar)] => (
    isa => "Str",
    is  => "rw",
);

sub create {
    return (
        KiokuDB::Test::Employee->new(
            name    => "joe",
            age     => 52,
            parents => [ KiokuDB::Test::Person->new(
                name => "mum",
                age  => 78,
            ) ],
            company => KiokuDB::Test::Company->new(
                name => "OHSOME SOFTWARE KTHX"
            ),
        ),
        KiokuDB::Test::Person->new(
            name => "oscar",
            age => 3,
        ),
    );
}

sub populate {
    my $self = shift;

    {
        my $s = $self->new_scope;

        my ( $joe, $oscar ) = $self->create;

        isa_ok( $joe, "KiokuDB::Test::Person" );
        isa_ok( $joe, "KiokuDB::Test::Employee" );

        isa_ok( $oscar, "KiokuDB::Test::Person" );

        my ( $joe_id, $oscar_id ) = $self->store_ok($joe, $oscar);

        $self->joe($joe_id);
        $self->oscar($oscar_id);

        $self->live_objects_are($joe, $joe->company, @{ $joe->parents }, $oscar);
    }

    $self->no_live_objects;
}

sub verify {
    my $self = shift;

    $self->txn_lives(sub {
        my ( $joe, $oscar ) = my @objs = $self->lookup_ok( $self->joe, $self->oscar );

        isa_ok( $joe, "KiokuDB::Test::Person" );
        isa_ok( $joe, "KiokuDB::Test::Employee" );

        isa_ok( $oscar, "KiokuDB::Test::Person" );

        my $entry = $self->directory->live_objects->object_to_entry($joe);

        ok( $entry->has_object, "entry is associated with object" );

        is( refaddr($entry->object), refaddr($joe), "the right object" );

        is( $joe->name, "joe", "name" );

        ok( my $parents = $joe->parents, "parents" );

        is( ref($parents), "ARRAY", "array ref" );

        is( scalar(@$parents), 1, "one parent" );

        isa_ok( $parents->[0], "KiokuDB::Test::Person" );

        is( $parents->[0]->name, "mum", "parent name" );

        ok( my $company = $joe->company, "company" );

        isa_ok( $company, "KiokuDB::Test::Company" );

        is( $oscar->name, "oscar", "name" );

        lives_ok { $self->directory->lookup("no_such_id") } "lookup of nonexistent ID is nonfatal";
    });
}
__PACKAGE__

__END__

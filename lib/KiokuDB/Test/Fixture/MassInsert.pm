#!/usr/bin/perl

package KiokuDB::Test::Fixture::MassInsert;
use Moose;

use Test::More;
use Test::Exception;

use Scalar::Util qw(refaddr);

use KiokuDB::Test::Person;

sub p {
    my @args = @_;
    unshift @args, "name" if @args % 2;
    KiokuDB::Test::Person->new(@args);
}

with qw(KiokuDB::Test::Fixture) => { -excludes => [qw/populate sort/] };

sub sort { 100 }

sub create {
    return map { p("person$_") } (1 .. 1024);
}

sub populate {
    my $self = shift;

    $self->txn_do(sub {
        my $s = $self->new_scope;

        my %people;
        @people{1 .. 1024} = $self->create;
        $self->store_ok(%people);
    });

}

sub verify {
    my $self = shift;

    $self->no_live_objects;

    $self->txn_do(sub {
        my $s = $self->new_scope;
        my $p = $self->lookup_ok(1 .. 1024);
    });

    $self->no_live_objects;
}

__PACKAGE__

__END__


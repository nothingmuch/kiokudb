#!/usr/bin/perl

use utf8;

package KiokuDB::Test::Fixture::Unicode;
use Moose;

use Encode;
use Test::More;

use KiokuDB::Test::Person;
use KiokuDB::Test::Employee;
use KiokuDB::Test::Company;

use namespace::clean -except => 'meta';

use constant required_backend_roles => qw(UnicodeSafe);

with qw(KiokuDB::Test::Fixture);

my $unicode = "משה";

sub create {

    return (
        KiokuDB::Test::Person->new(
            name => $unicode,
        ),
    );
}

sub verify {
    my $self = shift;

    my $dec = $self->lookup_ok( @{ $self->populate_ids } );

    isa_ok( $dec, "KiokuDB::Test::Person" );

    ok( Encode::is_utf8($dec->name), "preserved is_utf8" );
    is( $dec->name, $unicode, "correct value" );
}
__PACKAGE__

__END__

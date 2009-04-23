#!/usr/bin/perl

use utf8;

package KiokuDB::Test::Fixture::Binary;
use Moose;

use Encode;
use Test::More;

use KiokuDB::Test::Person;
use KiokuDB::Test::Employee;
use KiokuDB::Test::Company;

use namespace::clean -except => 'meta';

use constant required_backend_roles => qw(BinarySafe);

with qw(KiokuDB::Test::Fixture) => { excludes => 'required_backend_roles' };

my $utf8    = "חיים";

utf8::encode($utf8);

my $bytes = pack("C*", 39, 233, 120, 20, 40, 150, 0, 0, 0, 0, 0, 210, 211, 222, 1 );

sub create {

    return (
        KiokuDB::Test::Person->new(
            binary => $utf8,
        ),
        KiokuDB::Test::Person->new(
            binary => $bytes,
        ),
    );
}

sub verify {
    my $self = shift;

    $self->txn_lives(sub {
        my ( $enc, $bin ) = $self->lookup_ok( @{ $self->populate_ids } );

        isa_ok( $enc, "KiokuDB::Test::Person" );
        isa_ok( $bin, "KiokuDB::Test::Person" );

        ok( !Encode::is_utf8($enc->binary), "preserved utf8 bytes" );
        my $enc_decoded = Encode::decode( utf8 => $enc->binary );
        ok( Encode::is_utf8($enc_decoded), "decoded cleanly" );
        is( $enc_decoded, "חיים", "decoded to correct value" );

        ok( !Encode::is_utf8($bin->binary), "preserved arbitrary bytes" );
        is( length($bin->binary), length($bytes), "bytes not truncated" );
        is( unpack("H*", $bin->binary), unpack("H*", $bytes), "bytes equal" );
    });
}

__PACKAGE__

__END__

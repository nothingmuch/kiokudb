#!/usr/bin/perl

package KiokuDB::Backend::Serialize::YAML;
use Moose::Role;

use IO::Handle;

use YAML::XS qw(Load Dump);

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Backend::Serialize
    KiokuDB::Backend::Role::UnicodeSafe
    KiokuDB::Backend::TypeMap::Default::Storable
);

sub serialize {
    my ( $self, $entry ) = @_;

    Dump($entry);
}

sub deserialize {
    my ( $self, $blob ) = @_;

    return Load($blob);
}

sub serialize_to_stream {
    my ( $self, $fh, $entry ) = @_;
    $fh->print( $self->serialize($entry) );
}

has _deserialize_buffer => (
    isa => "ScalarRef",
    is  => "ro",
    default => sub { my $x = ''; \$x },
);

sub deserialize_from_stream {
    my ( $self, $fh ) = @_;

    local $_;
    local $/ = "\n";

    my $buf = $self->_deserialize_buffer;

    while ( <$fh> ) {
        if ( /^---/ and length($$buf) ) {
            my @data = $self->deserialize($$buf);
            $$buf = $_;
            return @data;
        } else {
            $$buf .= $_;
        }
    }

    if ( length $$buf ) {
        my @data = $self->deserialize($$buf);
        $$buf = '';
        return @data;
    } else {
        return;
    }
}

__PACKAGE__

__END__

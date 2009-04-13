package KiokuDB::Role::WithDigest;
use Moose::Role;

use Carp qw(croak);

use Digest::SHA qw(sha1_hex);

use MooseX::Clone::Meta::Attribute::Trait::NoClone;

use namespace::clean -except => 'meta';

has digest => (
    traits => [qw(NoClone)],
    isa => "Str",
    is  => "ro",
    lazy_build => 1,
);

requires 'digest_parts';

sub _build_digest {
    my $self = shift;
    $self->_compute_digest( $self->_build_digest_strings );
}

sub _compute_digest {
    my ( $self, @strings ) = @_;

    no warnings 'uninitialized';
    sha1_hex(join ":", ref($self), @strings);
}

sub _build_digest_strings {
    my $self = shift;

    my @parts = $self->digest_parts;

    my @strings;

    foreach my $part ( $self->digest_parts ) {
        if ( ref $part ) {
            push @strings, $self->_extract_digest_input_strings($part);
        } else {
            push @strings, $part;
        }
    }

    return @strings;
}

sub _extract_digest_input_strings {
    my ( $self, $part ) = @_;

    return $part unless ref $part;
    
    no warnings 'uninitialized';

    if ( blessed($part) ) {
        if ( $part->can("kiokudb_object_id") ) {
            return $part->kiokudb_object_id;
        } elsif ( $part->can("digest") ) {
            return $part->digest;
        } else {
            croak "Can't digest $part (no digest or ID method)";
        }
    } elsif ( ref $part eq 'ARRAY' ) {
        return join("", '[', join(",", map { $self->_extract_digest_input_strings($_) } @$part), ']');
    } elsif ( ref $part eq 'HASH' ) {
        return join("", '{', join(",", map { $_, ":", $self->_extract_digest_input_strings($part->{$_}) } sort keys %$part), '}');
    } else {
        croak "Can't digest $part (not a simple ref type)";
    }
}

__PACKAGE__

__END__

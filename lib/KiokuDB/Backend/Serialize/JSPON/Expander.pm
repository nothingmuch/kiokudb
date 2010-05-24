#!/usr/bin/perl

package KiokuDB::Backend::Serialize::JSPON::Expander;
use Moose;

use Carp qw(croak);
use Scalar::Util qw(weaken);

use KiokuDB::Entry;
use KiokuDB::Reference;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Backend::Serialize::JSPON::Converter);

sub expand_jspon {
    my ( $self, $data, @attrs ) = @_;

    return $self->_expander->($data, @attrs);
}

has _expander => (
    isa => "CodeRef",
    is  => "ro",
    lazy_build => 1,
);

sub _build__expander {
    my $self = shift;

    my $expander;

    my (
        $ref_field,     $id_field,         $data_field,
        $class_field,   $tied_field,       $root_field,
        $deleted_field, $class_meta_field, $class_version_field,
        $backend_data_field
      )
      = map { my $m = $_ . "_field"; $self->$m() }
      qw(ref id data class tied root deleted class_meta class_version backend_data);

    unless ( $self->inline_data ) {
        my $data_field_re = qr/\. \Q$data_field\E $/x;

        $expander = sub {
            my ( $data, @attrs ) = @_;

            if ( my $ref = ref($data) ) {
                if ( $ref eq 'HASH' ) {
                    if ( my $id = $data->{$ref_field} ) {
                        $id =~ s/$data_field_re//;
                        return KiokuDB::Reference->new( id => $id, ( $data->{weak} ? ( is_weak => 1 ) : () ) );
                    } elsif ( exists $data->{$class_field}
                        or exists $data->{$id_field}
                        or exists $data->{$tied_field}
                    ) {
                        if ( exists $data->{$class_field} ) {
                            # check the class more thoroughly here ...
                            my ($class, $version, $authority) = (split '-' => $data->{$class_field});
                            push @attrs, class => $class;

                            push @attrs, class_meta    => $data->{$class_meta_field} if exists $data->{$class_meta_field};
                            push @attrs, class_version => $data->{$class_meta_field} if exists $data->{$class_version_field};
                        }

                        push @attrs, id           => $data->{$id_field}                 if exists $data->{$id_field};
                        push @attrs, tied         => substr($data->{$tied_field}, 0, 1) if exists $data->{$tied_field};
                        push @attrs, root         => $data->{$root_field}    ? 1 : 0    if exists $data->{$root_field};
                        push @attrs, deleted      => $data->{$deleted_field} ? 1 : 0    if exists $data->{$deleted_field};
                        push @attrs, backend_data => $data->{$backend_data_field}       if exists $data->{$backend_data_field};

                        push @attrs, data => $expander->( $data->{$data_field} );

                        return KiokuDB::Entry->new( @attrs );
                    } else {
                        my %hash;

                        foreach my $key ( keys %$data ) {
                            my $unescaped = $key;
                            $unescaped =~ s/^public:://;

                            my $value = $data->{$key};
                            $hash{$unescaped} = ref($value) ? $expander->($value) : $value;
                        }

                        return \%hash;
                    }
                } elsif ( ref $data eq 'ARRAY' ) {
                    return [ map { ref($_) ? $expander->($_) : $_ } @$data ];
                }
            }

            return $data;
        }
    } else {
        $expander = sub {
            my ( $data, @attrs ) = @_;

            if ( my $ref = ref($data) ) {
                if ( $ref eq 'HASH' ) {

                    if ( my $id = $data->{$ref_field} ) {
                        return KiokuDB::Reference->new( id => $id, ( $data->{weak} ? ( is_weak => 1 ) : () ) );
                    } elsif ( exists $data->{$class_field}
                        or exists $data->{$id_field}
                        or exists $data->{$tied_field}
                    ) {
                        my %copy = %$data;

                        if ( exists $copy{$class_field} ) {
                            # check the class more thoroughly here ...
                            my ($class, $version, $authority) = (split '-' => delete $copy{$class_field});
                            push @attrs, class => $class;

                            push @attrs, class_meta => delete $copy{$class_meta_field} if exists $copy{$class_meta_field};
                        }

                        push @attrs, id      => delete $copy{$id_field}              if exists $copy{$id_field};
                        push @attrs, tied    => delete $copy{$tied_field}            if exists $copy{$tied_field};
                        push @attrs, root    => delete $copy{$root_field}    ? 1 : 0 if exists $copy{$root_field};
                        push @attrs, deleted => delete $copy{$deleted_field} ? 1 : 0 if exists $copy{$deleted_field};

                        push @attrs, data => $expander->( \%copy );

                        return KiokuDB::Entry->new( @attrs );
                    } else {
                        my %hash;

                        foreach my $key ( keys %$data ) {
                            my $unescaped = $key;
                            $unescaped =~ s/^public:://;

                            my $value = $data->{$key};
                            $hash{$unescaped} = ref($value) ? $expander->($value) : $value;
                        }

                        return \%hash;
                    }
                } elsif ( ref $data eq 'ARRAY' ) {
                    return [ map { ref($_) ? $expander->($_) : $_ } @$data ];
                }
            }

            return $data;
        }
    }

    my $copy = $expander;
    weaken($expander);

    return $copy;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Serialize::JSPON::Expander - Inflate JSPON to entry
data.

=head1 SYNOPSIS

    my $c = KiokuDB::Backend::Serialize::JSPON::Expander->new(
        id_field => "_id",
    );

    my $entry = $c->collapse_jspon($hashref);

=head1 DESCRIPTION

This object is used by L<KiokuDB::Backend::Serialize::JSPON> to expand JSPON
compliant hash references to L<KiokuDB::Entry> objects.

=head1 ATTRIBUTES

See L<KiokuDB::Backend::Serialize::JSPON::Converter> for attributes shared by
L<KiokuDB::Backend::Serialize::JSPON::Collapser> and
L<KiokuDB::Backend::Serialize::JSPON::Expander>.

=head1 METHODS

=over 4

=item expand_jspon $hashref

Recursively inlates the hash reference, returning a L<KiokuDB::Entry> object.

=back

#!/usr/bin/perl

package KiokuDB::Entry;
use Moose;

use Moose::Util::TypeConstraints;

use MooseX::Types -declare => ['Tied'];

use namespace::clean -except => 'meta';

has id => (
    isa => "Str",
    is  => "ro",
    writer    => "_id",
    clearer   => "clear_id",
    predicate => "has_id",
);

has root => (
    isa => "Bool",
    is  => "rw",
    lazy_build => 1,
);

sub _build_root {
    my $self = shift;

    if ( $self->has_id and my $prev = $self->prev ) {
        return $prev->root;
    } else {
        return 0;
    }
}

has deleted => (
    isa => "Bool",
    is  => "ro",
    writer => "_deleted",
);

has data => (
    is  => "ro",
    writer    => "_data",
    predicate => "has_data",
);

has class => (
    isa => "Str",
    is  => "ro",
    writer    => "_class",
    predicate => "has_class",
);

has class_meta => (
    isa => "HashRef",
    is  => "ro",
    writer    => "_class_meta",
    predicate => "has_class_meta",
);

my @tied = ( map { substr($_, 0, 1) } qw(HASH SCALAR ARRAY GLOB) );

enum Tied, @tied;

coerce Tied, from Str => via { substr($_, 0, 1) };

has tied => (
    isa => Tied,
    is  => "ro",
    coerce    => 1,
    writer    => "_tied",
    predicate => "has_tied",
);

has backend_data => (
    isa => "Ref",
    is  => "rw",
    predicate => "has_backend_data",
    clearer   => "clear_backend_data",
);

has prev => (
    isa => __PACKAGE__,
    is  => "rw",
    predicate => "has_prev",
);

has object => (
    isa => "Any",
    is  => "rw",
    weak_ref => 1,
    predicate => "has_object",
);

sub deletion_entry {
    my $self = shift;

    ( ref $self )->new(
        id   => $self->id,
        prev => $self,
        deleted => 1,
        ( $self->has_object       ? ( object       => $self->object       ) : () ),
        ( $self->has_backend_data ? ( backend_data => $self->backend_data ) : () ),
    );
}

has _references => (
    isa => "ArrayRef",
    is  => "ro",
    lazy_build => 1,
);

sub _build__references {
    my $self = shift;

    no warnings 'uninitialized';
    if ( $self->class eq 'KiokuDB::Set::Stored' ) { # FIXME should the typemap somehow handle this?
        return [ map { KiokuDB::Reference->new( id => $_ ) } @{ $self->data } ];
    } else {
        my @refs;

        my @queue = $self->data;

        while ( @queue ) {
            my $next = pop @queue;

            my $ref = ref $next;
            if ( $ref eq 'HASH' ) {
                push @queue, grep { ref } values %$next;
            } elsif ( $ref eq 'ARRAY' ) {
                push @queue, grep { ref } @$next;
            } elsif ( $ref eq 'KiokuDB::Entry' ) {
                push @refs, $next->references;
            } elsif ( $ref eq 'KiokuDB::Reference' ) {
                push @refs, $next;
            }
        }

        return \@refs;
    }
}

sub references {
    my $self = shift;

    return @{ $self->_references };
}

has _referenced_ids => (
    isa => "ArrayRef",
    is  => "ro",
    lazy_build => 1,
);

sub _build__referenced_ids {
    my $self = shift;

    no warnings 'uninitialized';
    if ( $self->class eq 'KiokuDB::Set::Stored' ) { # FIXME should the typemap somehow handle this?
        return $self->data;
    } else {
        return [ map { $_->id } $self->references ];
    }
}

sub referenced_ids {
    my $self = shift;

    @{ $self->_referenced_ids };
}

use constant _version => 1;

use constant _root_b      => 0x01;
use constant _deleted_b   => 0x02;

use constant _tied_shift => 2;
use constant _tied_mask => 0x03 << _tied_shift;

my %tied; @tied{@tied} = ( 1 .. scalar(@tied) );

sub _pack {
    my $self = shift;

    my $flags = 0;

    $flags |= _root_b    if $self->root;
    $flags |= _deleted_b if $self->deleted;

    if ( $self->has_tied ) {
        $flags |= $tied{$self->tied} << _tied_shift;
    }

    no warnings 'uninitialized';
    pack( "C C w/a* w/a*", _version, $flags, $self->id, $self->class );
}

sub _unpack {
    my ( $self, $packed ) = @_;

    my ( $v, $body ) = unpack("C a*", $packed);

    if ( $v == _version ) {
        my ( $flags, $id, $class, $extra ) = unpack("C w/a w/a a*", $body);

        return $self->_unpack_old($packed) if length($extra);

        $self->_id($id) if length($id);

        $self->_class($class) if length($class);

        $self->root($flags & _root_b);
        $self->_deleted(1) if $flags & _deleted_b;

        if ( my $tied = ( $flags & _tied_mask ) >> _tied_shift ) {
            $self->_tied( $tied[$tied - 1] );
        }
    } else {
        $self->_unpack_old($packed);
    }
}


sub _pack_old {
    my $self = shift;

    no warnings 'uninitialized';
    join(",",
        $self->id,
        !!$self->root,
        $self->class,
        $self->tied,
        !!$self->deleted,
    );
}

sub _unpack_old {
    my ( $self, $packed ) = @_;

    my ( $id, $root, $class, $tied, $deleted ) = split ',', $packed;

    die "bad entry format: $packed" if $root and $root ne '1';
    die "bad entry format: $packed" if $deleted and $deleted ne '1';

    $self->_id($id) if $id;
    $self->root(1) if $root;
    $self->_class($class) if $class;
    $self->_tied(substr($tied, 0, 1)) if $tied;
    $self->_deleted(1) if $deleted;
}

sub STORABLE_freeze {
    my ( $self, $cloning ) = @_;

    return (
        $self->_pack,
        [
            ( $self->has_data         ? $self->data         : undef ),
            ( $self->has_backend_data ? $self->backend_data : undef ),
            ( $self->has_class_meta   ? $self->class_meta   : undef ),
        ],
    );
}

sub STORABLE_thaw {
    my ( $self, $cloning, $attrs, $refs ) = @_;

    $self->_unpack($attrs);

    if ( $refs ) {
        my ( $data, $backend_data, $meta ) = @$refs;
        $self->_data($data) if defined $data;
        $self->backend_data($backend_data) if ref $backend_data;
        $self->_class_meta($meta) if ref $meta;
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Entry - An entry in the database

=head1 SYNOPSIS

    KiokuDB::Entry->new(
        id => ...,
        data => ...
    );

=head1 DESCRIPTION

This object provides the meta data for a single storage entry.

=head1 ATTRIBUTES

=over 4

=item id

The UUID for the entry.

If there is no ID then the entry is intrinsic.

=item root

Whether or not this is a member of the root set (not subject to garbage
collection, because storage was explicitly requested).

=item data

A simplified data structure modeling this object/reference. This is a tree, not
a graph, and has no shared data (JSON compliant). All references are symbolic,
using a L<KiokuDB::Reference> object with UIDs as the
address space.

=item class

If the entry is blessed, this contains the class of that object.

In the future this might be a complex structure for anonymous classes, e.g. the
class and the runtime roles.

=item class_meta

Optional information such as runtime roles to be applied to the object is
stored in this hashref.

=item tied

One of C<HASH>, C<ARRAY>, C<SCALAR> or C<GLOB>.

C<data> is assumed to be a reference or an intrinsic entry for the object
driving the tied structure (e.g. the C<tied(%hash)>).

=item prev

Contains a link to a L<KiokuDB::Entry> objects that precedes this one.

The last entry that was loaded from the store, or successfully written to the
store for a given UUID is kept in the live object set.

The collapser creates transient Entry objects, which if written to the store
successfully are replace the previous one.

=item backend_data

Backends can use this to store additional meta data as they see fit.

For instance, this is used in the CouchDB backend to track entry revisions for
the opportunistic locking, and in L<KiokuDB::Backend::BDB::GIN> to to store
extracted keys.

=item deleted

Used for marking entries for deletion.

Deletion entries can be generated using the C<deletion_entry> method, which
creates a new derived entry with no data but retaining the ID.

=back

=cut

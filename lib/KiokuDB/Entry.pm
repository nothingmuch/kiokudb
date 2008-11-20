#!/usr/bin/perl

package KiokuDB::Entry;
use Moose;

use Moose::Util::TypeConstraints;

use namespace::clean -except => 'meta';

has id => (
    isa => "Str",
    is  => "rw",
    clearer => "clear_id",
);

has root => (
    isa => "Bool",
    is  => "rw",
);

has deleted => (
    isa => "Bool",
    is  => "rw",
);

has data => (
    isa => "Ref",
    is  => "rw",
    predicate => "has_data",
);

has class => (
    isa => "Str",
    is  => "rw",
    predicate => "has_class",
);

my @tied = ( qw(HASH SCALAR ARRAY GLOB) );

has tied => (
    isa => enum(\@tied),
    is  => "rw",
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

        # overkill
        use Data::Visitor::Callback;
        Data::Visitor::Callback->new(
            'KiokuDB::Reference' => sub { push @refs, $_ },
            'KiokuDB::Entry'     => sub { push @refs, $_->references },
        )->visit($self->data);

        return \@refs;
    }
}

sub references {
    my $self = shift;

    return @{ $self->_references };
}

use constant _version => 1;

use constant _root      => 0x01;
use constant _deleted   => 0x02;

use constant _tied_shift => 2;
use constant _tied_mask => 0x03 << _tied_shift;

my %tied; @tied{@tied} = ( 1 .. scalar(@tied) );

my %tied_old; @tied_old{@tied} = qw(H S A G);
my %tied_old_r = reverse %tied_old;

sub _pack {
    my $self = shift;

    my $flags = 0;

    $flags |= _root if $self->root;
    $flags |= _deleted if $self->deleted;

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

        $self->id($id) if length($id);

        $self->class($class) if length($class);

        $self->root(1) if $flags & _root;
        $self->deleted(1) if $flags & _deleted;

        if ( my $tied = ( $flags & _tied_mask ) >> _tied_shift ) {
            $self->tied( $tied[$tied - 1] );
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
        $tied_old{$self->tied},
        !!$self->deleted,
    );
}

sub _unpack_old {
    my ( $self, $packed ) = @_;

    my ( $id, $root, $class, $tied, $deleted ) = split ',', $packed;

    die "bad entry format: $packed" if $root and $root ne '1';
    die "bad entry format: $packed" if $deleted and $deleted ne '1';
    die "bad entry format: $packed" if $tied and not exists $tied_old_r{$tied};

    $self->id($id) if $id;
    $self->root(1) if $root;
    $self->class($class) if $class;
    $self->tied($tied_old_r{$tied}) if $tied;
    $self->deleted(1) if $deleted;
}

sub STORABLE_freeze {
    my ( $self, $cloning ) = @_;

    return (
        $self->_pack,
        [
            ( $self->has_data         ? $self->data         : undef ),
            ( $self->has_backend_data ? $self->backend_data : undef ),
        ],
    );
}

sub STORABLE_thaw {
    my ( $self, $cloning, $attrs, $refs ) = @_;

    $self->_unpack($attrs);

    if ( $refs ) {
        my ( $data, $backend_data ) = @$refs;
        $self->data($data) if ref $data;
        $self->backend_data($backend_data) if ref $backend_data;
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

=back

=cut

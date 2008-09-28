#!/usr/bin/perl

package KiokuDB::Backend;
use Moose::Role;

use Moose::Util::TypeConstraints;

use namespace::clean -except => 'meta';

coerce ( __PACKAGE__,
    from HashRef => via {
        my %p = %$_;
        my $class = delete $p{class} || die "Can't coerce backend from hash without a 'class' parameter";

        do {
            local $@;
            eval {
                Class::MOP::load_class("KiokuDB::Backend::$class");
                "KiokuDB::Backend::$class"->new(%p);
            }
        } or do {
            Class::MOP::load_class($class);
            $class->new(%p);
        }
    },
    from Str => via {
        Class::MOP::load_class($_);
        $_->new;
    },
);

requires qw(
    exists
    insert
    get
    delete
);

sub new_from_dsn {
    my ( $class, $params, @extra ) = @_;

    if ( defined $params ) {
        $class->new_from_dsn_params($class->parse_dsn_params($params), @extra);
    } else {
        return $class->new;
    }
}

sub new_from_dsn_params {
    my ( $class, @params ) = @_;
    $class->new(@params);
}

sub parse_dsn_params {
    my ( $self, $params ) = @_;

    my @pairs = split ';', $params;

    return map {
        my ( $key, $value ) = /(\w+)(?:=(.*))/;
        length($value) ? ( $key, $value ) : ( $key => 1 );
    } @pairs;
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend - Backend interface role

=head1 SYNOPSIS

    package KiokuDB::Backend::Foo;
    use Moose;

    with qw(KiokuDB::Backend);

    sub insert { ... }

    sub get { ... }

    sub delete { ... }

    sub exists { ... }

    my $dir = KiokuDB->new(
        backend => KiokuDB::Backend::Foo->new( );
    );

=head1 DESCRIPTION

L<KiokuDB> is designed to be fairly backend agnostic.

This role defines the minimal API for writing new backends.

=head1 TRANSACTIONS

This role is supplemented by L<KiokuDB::Backend::Transactional>, a role for
first class transaction support that issues rollbacks using the
L<KiokuDB::Entry> objects.

=head1 QUERYING

This role is supplemented by L<KiokuDB::Backend::Query>, a role for
backend specific queries.

L<KiokuDB::Backend::Query::Simple> provides a universal query api for
backends that can perform property based lookup.

L<KiokuDB::Backend::Query::GIN> is a role for using L<Search::GIN> based
indexing/querying with backends that do not natively support querying.

=head1 METHODS

=over 4

=item get @ids

Retrieve the L<KiokuDB::Entry> objects associated with the @ids.

If any other error is encountered, this method should die.

The backend may store private data in C<backend_data>, to be used in a subsequent update.

Returns a list of L<KiokuDB::Entry>, with the order corresponding to C<@ids>.
If an entry does not exist then C<undef> should be returned in place of it. The
backend may abort retrieval on the first non existent entry.

=item insert @entries

Insert entries to the store.

If the backend is transactional this operation should be atomic with respect to
the inserted/updated data.

The backend is required to store the data in the fields C<data>, C<class> using
the key in C<id>.

Entries which have an entry in C<prev> denote updates (either objects that have
been previously stored, or objects that were looked up). The previous entry may
be used to compare state for issuing a partial update, and will contain the
value of C<backend_data> for any other state tracking.

C<object> is a weak reference to the object this entry is representing, and may
be used for high level indexing. Do not use this field for storage.

If this backend implements some form of garbage collection, C<root> denotes
that the objects is part of the root set.

After all entries have been successfully written, C<backend_data> should be set
if necessary just as in C<get>.

Has no return value.

If C<insert> does not die the write is assumed to be successful.

=item delete @ids_or_entries

Delete the specified IDs or entries.

If the user provided objects then entries will be passed in. Any associated
state the entries may have (e.g. a revision) should be used in order to enforce
atomicity with respect to the time when the objects were loaded.

After all entries have been successfully deleted, C<deleted> should be set. The
entry passed in is the same one as was loaded by C<get> or last written by
C<insert>, so it is already up to date in the live objects.

Has no return value.

If C<delete> does not die the write is assumed to be successful.

=item exists @ids

Check for existence of the specified IDs, without retrieving their data.

Returns a list of true or false values.

=back

=head1 SHARED BACKENDS

A backend may be shared by several L<KiokuDB> instances, each with its own
distinct live object set. The backend may choose to share cached entry B<data>,
as that is not mutated by L<KiokuDB::Linker>, but not the L<KiokuDB::Entry>
instances themselves.

=cut



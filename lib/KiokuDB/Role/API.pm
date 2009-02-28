package KiokuDB::Role::API;
use Moose::Role;

use namespace::clean -except => 'meta';

requires qw(
    new_scope
    txn_do

    lookup

    exists

    store

    insert
    update
    deep_update

    delete

    is_root

    set_root
    unset_root

    search

    all_objects
    root_set

    grep
    scan

    clear_live_objects

    new_scope

    object_to_id
    objects_to_ids

    id_to_object
    ids_to_objects

    live_objects

    directory
);

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Role::API - Role for L<KiokuDB> api (used to setup delegations).

=head1 SYNOPSIS

    has directory => (
        isa => "KiokuDB",
        handles => "KiokuDB::Role::API",
    );

=head1 DESCRIPTION

This role provides C<requires> declarations for the runtime methods of
L<KiokuDB>. This is useful for setting up delegations.

This is used in e.g. L<KiokuX::User>.

=head1 METHODS

=over 4

=item new_scope

=item txn_do

=item lookup

=item exists

=item store

=item insert

=item update

=item deep_update

=item delete

=item is_root

=item set_root

=item unset_root

=item search

=item all_objects

=item root_set

=item grep

=item scan

=item clear_live_objects

=item new_scope

=item object_to_id

=item objects_to_ids

=item id_to_object

=item ids_to_objects

=item live_objects

=item directory

The C<directory> method should be used to fetch the actual L<KiokuDB> delegate.
This will work no matter how deeply it is nested.

=back

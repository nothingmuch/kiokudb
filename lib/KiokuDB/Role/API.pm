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

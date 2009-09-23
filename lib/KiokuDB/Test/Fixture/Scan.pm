#!/usr/bin/perl

package KiokuDB::Test::Fixture::Scan;
use Moose;

use Test::More;
use Test::Moose;

use KiokuDB::Test::Person;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Test::Fixture) => { excludes => 'required_backend_roles' };

use constant required_backend_roles => qw(Clear Scan);

sub create {
    my $self = shift;

    ( map { KiokuDB::Test::Person->new(%$_) }
        { name => "foo", age => 3 },
        { name => "bar", age => 3 },
        { name => "gorch", age => 5, friends => [ KiokuDB::Test::Person->new( name => "quxx", age => 6 ) ] },
    );
}

before populate => sub {
    my $self = shift;
    $self->backend->clear;
};

sub verify {
    my $self = shift;

    $self->txn_lives(sub {
        my $root = $self->root_set;

        does_ok( $root, "Data::Stream::Bulk" );

        my @objs = $root->all;

        my @ids = $self->objects_to_ids(@objs);

        is_deeply(
            [ sort map { $_->name } @objs ],
            [ sort qw(foo bar gorch) ],
            "root set",
        );

        is_deeply(
            [ sort $self->backend->root_entry_ids->all ],
            [ sort @ids ],
        );
    });

    $self->txn_lives(sub {
        my $child_entries = $self->backend->child_entries;

        does_ok( $child_entries, "Data::Stream::Bulk" );
        my $children = $child_entries->filter(sub {[ $self->directory->linker->register_and_expand_entries(@$_) ]});

        my @objs = $children->all;

        my @ids = $self->objects_to_ids(@objs);

        is_deeply(
            [ sort map { $_->name } @objs ],
            [ sort qw(quxx) ],
            "child entries",
        );

        is_deeply(
            [ sort $self->backend->child_entry_ids->all ],
            [ sort @ids ],
        );
    });

    $self->txn_lives(sub {
        my $all_entries = $self->backend->all_entries;

        does_ok( $all_entries, "Data::Stream::Bulk" );

        my $all = $all_entries->filter(sub {[ $self->directory->linker->register_and_expand_entries(@$_) ]});

        my @objs = $all->all;

        my @ids = $self->objects_to_ids(@objs);

        is_deeply(
            [ sort map { $_->name } @objs ],
            [ sort qw(foo bar gorch quxx) ],
            "all entries",
        );

        is_deeply(
            [ sort $self->backend->all_entry_ids->all ],
            [ sort @ids ],
        );
    });
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__


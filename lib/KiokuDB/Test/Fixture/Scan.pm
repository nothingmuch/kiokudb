#!/usr/bin/perl

package KiokuDB::Test::Fixture::Scan;
use Moose;

use Test::More;
use Test::Moose;

use KiokuDB::Test::Person;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Test::Fixture);

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

    my $root = $self->root_set;

    does_ok( $root, "Data::Stream::Bulk" );

    is_deeply(
        [ sort map { $_->name } $root->all ],
        [ sort qw(foo bar gorch) ],
        "root set",
    );

    my $child_entries = $self->backend->child_entries;

    does_ok( $child_entries, "Data::Stream::Bulk" );

    my $children = $child_entries->filter(sub {[ $self->directory->linker->load_entries(@$_) ]});

    is_deeply(
        [ sort map { $_->name } $children->all ],
        [ sort qw(quxx) ],
        "child entries",
    );

    my $all_entries = $self->backend->all_entries;

    does_ok( $all_entries, "Data::Stream::Bulk" );

    my $all = $all_entries->filter(sub {[ $self->directory->linker->load_entries(@$_) ]});

    is_deeply(
        [ sort map { $_->name } $all->all ],
        [ sort qw(foo bar gorch quxx) ],
        "all entries",
    );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__


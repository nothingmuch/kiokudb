#!/usr/bin/perl

package KiokuDB::Test::Fixture;
use Moose::Role;

use Test::More;
use Test::Exception;

sub _lives_and_ret (&;$) {
    my ( $sub, @args ) = @_;

    my @ret;
    my $wrapped = sub { @ret = $sub->() };

    local $Test::Builder::Level = $Test::Builder::Level + 2;
    &lives_ok($wrapped, @args);

    return ( ( @ret == 1 ) ? $ret[0] : @ret );
}

use namespace::clean -except => 'meta';

requires qw(create verify);

sub sort { 0 }

sub required_backend_roles { return () }

has populate_ids => (
    isa => "ArrayRef[Str]",
    is  => "rw",
    predicate => "has_populate_ids",
    clearer   => "clear_populate_ids",
);

sub populate {
    my $self = shift;

    {
        my $s = $self->new_scope;

        my @objects = $self->create;

        my @ids = $self->store_ok(@objects);

        $self->populate_ids(\@ids);
    }

    $self->no_live_objects;
}

sub name {
    my $self = shift;
    my $class = ref($self) || $self;
    $class =~ s{KiokuDB::Test::Fixture::}{};
    return $class;
}

sub skip_fixture {
    my ( $self, $reason, $count ) = @_;

    skip $self->name . " fixture ($reason)", $count || 1
}

sub precheck {
    my $self = shift;

    my $backend = $self->backend;

    my @missing;

    foreach my $role ( $self->required_backend_roles ) {
        push @missing, $role unless $backend->does($role) or $backend->does("KiokuDB::Backend::$role");
    }

    if ( @missing ) {
        $_ =~ s/^KiokuDB::Backend::// for @missing;
        $self->skip_fixture("Backend does not implement required roles (@missing)")
    }
}

sub run {
    my $self = shift;

    SKIP: {
        local $Test::Builder::Level = $Test::Builder::Level + 1;

        my $txn = $self->backend->does("KiokuDB::Backend::TXN") && $self->backend->txn_begin;

        $self->precheck;

        $self->clear_live_objects;

        is_deeply( [ $self->live_objects ], [ ], "no live objects at start of " . $self->name . " fixture" );

        lives_ok {
            my $s = $self->new_scope;
            local $Test::Builder::Level = $Test::Builder::Level - 1;
            $self->populate;
            $self->verify;
        } "no error in fixture";

        $self->backend->txn_commit($txn) if $txn;

        is_deeply( [ $self->live_objects ], [ ], "no live objects at end of " . $self->name . " fixture" );

        $self->clear_live_objects;
    }
}

has directory => (
    is  => "ro",
    isa => "KiokuDB",
    handles => [qw(
        lookup exists
        store
        insert update delete
        
        clear_live_objects
        
        backend
        resolver
        linker
        collapser

        search
        simple_search
        backend_search

        root_set
        scan
        grep

        new_scope

        txn_do
    )],
);

sub live_objects {
    shift->directory->live_objects->live_objects
}

sub update_live_objects {
    my $self = shift;

    _lives_and_ret { $self->update( $self->live_objects ) } "updated live objects";
}

sub store_ok {
    my ( $self, @objects ) = @_;

    local $Test::Builder::Level = 1;

    _lives_and_ret { $self->store( @objects ) } "stored " . scalar(grep { ref } @objects) . " objects";
}

sub update_ok {
    my ( $self, @objects ) = @_;

    _lives_and_ret { $self->update( @objects ) } "updated " . scalar(@objects) . " objects";
}

sub delete_ok {
    my ( $self, @objects ) = @_;

    _lives_and_ret { $self->delete( @objects ) } "deleted " . scalar(@objects) . " objects";
}

sub lookup_ok {
    my ( $self, @ids ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @ret;
    _lives_and_ret { @ret = $self->lookup( @ids ) } "lookup " . scalar(@ids) . " objects";

    is( scalar(grep { ref } @ret), scalar(@ids), "all lookups succeeded" );

    return ( ( @ret == 1 ) ? $ret[0] : @ret );
}

sub exists_ok {
    my ( $self, @ids ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    is( scalar(grep { defined } $self->exists(@ids)), scalar(@ids), "@ids exist in DB" );
}

sub deleted_ok {
    my ( $self, @ids ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    is( scalar(grep { !$_ } $self->exists(@ids)), scalar(@ids), "@ids do not exist in DB" );
}

sub lookup_obj_ok {
    my ( $self, $id, $class ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok( my $obj = $self->lookup($id), "lookup $id" );

    isa_ok( $obj, $class ) if $class;

    return $obj;
}

sub no_live_objects {
    my $self = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    is_deeply( [ $self->live_objects ], [ ], "no live objects" );
}

sub live_objects_are {
    my ( $self, @objects ) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    is_deeply( [ sort $self->live_objects ], [ sort @objects ], "correct live objects" );
}

__PACKAGE__

__END__

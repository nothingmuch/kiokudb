#!/usr/bin/perl

package KiokuDB::Test::Fixture;
use Moose::Role;

use Test::More;
use Test::Exception;

use Data::Structure::Util qw(circular_off);

sub _lives_and_ret (&;$) {
    my ( $sub, @args ) = @_;

    my @ret;
    my $wrapped = sub { @ret = $sub->() };

    local $Test::Builder::Level = $Test::Builder::Level + 2;
    &lives_ok($wrapped, @args);

    return ( ( @ret == 1 ) ? $ret[0] : @ret );
}

use namespace::clean -except => 'meta';

requires qw(create populate verify);

sub sort { 0 }

sub name {
    my $self = shift;
    my $class = ref($self) || $self;
    $class =~ s{KiokuDB::Test::Fixture::}{};
    return $class;
}

sub precheck {
    my $self = shift;
}

sub run {
    my $self = shift;

    SKIP: {
        local $Test::Builder::Level = $Test::Builder::Level + 1;

        $self->precheck;

        $self->clear_live_objects;

        is_deeply( [ $self->live_objects ], [ ], "no live objects at start of " . $self->name );

        lives_ok {
            local $Test::Builder::Level = $Test::Builder::Level - 1;
            $self->populate;
            $self->verify;
        } "no error in fixture";

        is_deeply( [ $self->live_objects ], [ ], "no live objects at end of " . $self->name );

        $self->clear_live_objects;
    }
}

has directory => (
    is  => "ro",
    isa => "KiokuDB",
    handles => [qw(insert store update lookup exists delete clear_live_objects)],
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

    _lives_and_ret { $self->store( @objects ) } "stored " . scalar(@objects) . " objects";
}

sub update_ok {
    my ( $self, @objects ) = @_;

    _lives_and_ret { $self->update( @objects ) } "updated " . scalar(@objects) . " objects";
}

sub delete_ok {
    my ( $self, @objects ) = @_;

    _lives_and_ret { $self->delete( @objects ) } "deleted " . scalar(@objects) . " objects";
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

sub lookup_ok {
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

#!/usr/bin/perl

package MooseX::Storage::Directory::Test::Fixture;
use Moose::Role;

use Data::Structure::Util qw(circular_off);

use namespace::clean -except => 'meta';

requires qw(populate verify);

has directory => (
    is  => "ro",
    isa => "MooseX::Storage::Directory",
    handles => [qw(live_objects)],
);

sub DEMOLISH {
    my $self = shift;
    circular_off([ $self->live_objects->live_objects ]);
}

__PACKAGE__

__END__

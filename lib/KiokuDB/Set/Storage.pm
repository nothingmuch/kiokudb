#!/usr/bin/perl

package KiokuDB::Set::Storage;
use Moose::Role;

use Set::Object;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Set);

has _linker => (
    isa => "KiokuDB::Linker",
    is  => "ro",
    required => 1,
);

has _live_objects => (
    isa => "KiokuDB::LiveObjects",
    is  => "ro",
    lazy_build => 1,
);

sub _build__live_objects {
    my $self = shift;
    $self->_linker->live_objects;
}

has _live_object_scope => (
    isa => "KiokuDB::LiveObjects::Scope",
    is  => "ro",
    lazy_build => 1,
);

sub _build__live_object_scope {
    my $self = shift;
    $self->_live_objects->current_scope;
}

sub BUILD { shift->_live_object_scope } # early

has _objects => (
    isa => "Set::Object",
    is  => "ro",
    init_arg => "set",
    writer   => "_set_objects",
    default => sub { Set::Object->new },
    #handles => [qw(size clear)],
);

sub clear { shift->_objects->clear }
sub size  { shift->_objects->size }

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Set::Storage - 

=head1 SYNOPSIS

	use KiokuDB::Set::Storage;

=head1 DESCRIPTION

=cut



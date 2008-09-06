#!/usr/bin/perl

package KiokuDB::Backend::Scan;
use Moose::Role;

use namespace::clean -except => 'meta';

requires "root_set";

sub scan {
    my $self = shift;

    my $stream = $self->root_set;

    $stream->filter(sub { [ $self->get(@$_) ] });
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Scan - Root set iteration

=head1 SYNOPSIS

	with qw(KiokuDB::Backend::Scan);

    sub scan {
        my $self = shift;

        # return all root set entries
        return Data::Stream::Bulk::Foo->new(...);
    }

=head1 DESCRIPTION

=cut



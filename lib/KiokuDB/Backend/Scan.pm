#!/usr/bin/perl

package KiokuDB::Backend::Scan;
use Moose::Role;

use namespace::clean -except => 'meta';

requires "all_entries";

sub root_entries {
    my $self = shift;
    return $self->all_entries->filter(sub {[ grep { $_->root } @$_ ]});
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Scan - Root set iteration

=head1 SYNOPSIS

	with qw(KiokuDB::Backend::Scan);

    sub root_entries {
        my $self = shift;

        # return all root set entries
        return Data::Stream::Bulk::Foo->new(...);
    }

=head1 DESCRIPTION

=cut



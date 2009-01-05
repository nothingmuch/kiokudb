#!/usr/bin/perl

package KiokuDB::Stream::Objects;
use Moose;

use namespace::clean -except => 'meta';

has directory => (
    isa => "KiokuDB",
    is  => "ro",
    required => 1,
);

has entry_stream => (
	does => "Data::Stream::Bulk",
	is   => "ro",
	required => 1,
	handles  => [qw(is_done loaded)],
);

has linker => (
    isa => "KiokuDB::Linker",
    is  => "ro",
    lazy_build => 1,
);

sub _build_linker {
    my $self = shift;

    $self->directory->linker;
}

has _scope => (
    isa => "KiokuDB::LiveObjects::Scope",
    writer  => "_scope",
    clearer => "_clear_scope",
);

with qw(Data::Stream::Bulk);

sub next {
	my $self = shift;

    $self->_clear_scope;

    my $entries = $self->entry_stream->next || return;;

    if ( @$entries ) {
        $self->_scope( $self->directory->new_scope );
        return [ $self->linker->load_entries(@$entries) ];
    } else {
        return;
    }
}


__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Stream::Objects - L<Data::Stream::Bulk> with live object management.

=head1 DESCRIPTION

This class is for object streams coming out of L<KiokuDB>.

C<new_scope> is called once for each block, and then cleared.

=cut



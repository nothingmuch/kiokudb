#!/usr/bin/perl

package KiokuDB::Backend::CouchDB;
use Moose;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Backend
    KiokuDB::Backend::Serialize::JSPON
    KiokuDB::Role::StorageUUIDs
);

has db => (
    isa => "Net::CouchDB::DB",
    is  => "ro",
    handles => [qw(document)],
);

sub delete {
    my ( $self, @ids_or_entries ) = @_;

    my @docs = map { ref($_) ? $_->backend_data : $self->document($_) } @ids_or_entries;

    $self->db->bulk({ delete => \@docs });
}

sub insert {
    my ( $self, @entries ) = @_;

    my ( @update, @insert, @insert_entries );

    foreach my $entry ( @entries ) {
        my $collapsed = $self->collapse_jspon($entry);
        $collapsed->{_id} = delete $collapsed->{id}; # FIXME
        $collapsed->{class} = delete $collapsed->{__CLASS__};

        if ( my $prev = $entry->prev ) {
            my $doc = $prev->backend_data;
            %$doc = %$collapsed;
            $entry->backend_data($prev->backend_data);
            push @update, $doc;
        } else {
            push @insert, $collapsed;
            push @insert_entries, $entry;
        }
    }

    my @new_docs = $self->db->bulk({ update => \@update, insert => \@insert });

    foreach my $entry ( @insert_entries ) {
        $entry->backend_data(shift @new_docs);
    }
}

sub get {
    my ( $self, @uids ) = @_;

    my @ret;

    # FIXME bulk, and test
    foreach my $uid ( @uids ) {
        my $doc = $self->document($uid) || return;
        my %doc = %$doc;
        $doc{__CLASS__} = delete $doc{class};
        $doc{id} = $doc->id;
        my $entry = $self->expand_jspon(\%doc, backend_data => $doc);
        push @ret, $entry;
    }

    return @ret;
}

sub exists {
    my ( $self, @uids ) = @_;
    map { defined $self->document($_) } @uids;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__


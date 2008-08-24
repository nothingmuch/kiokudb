#!/usr/bin/perl

package MooseX::Storage::Directory::Backend::CouchDB;
use Moose;

use namespace::clean -except => 'meta';

with qw(
    MooseX::Storage::Directory::Backend
    MooseX::Storage::Directory::Backend::Serialize::JSPON
    MooseX::Storage::Directory::Role::StorageUUIDs
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

    $_->update_live_objects for @entries;
}

sub get {
    my ( $self, $uid ) = @_;
    my $doc = $self->document($uid) || return;
    my %doc = %$doc;
    $doc{__CLASS__} = delete $doc{class};
    $doc{id} = $doc->id;
    my $entry = $self->expand_jspon(\%doc, backend_data => $doc);
    return $entry;
}

sub exists {
    my ( $self, @uids ) = @_;
    map { defined $self->document($_) } @uids;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__


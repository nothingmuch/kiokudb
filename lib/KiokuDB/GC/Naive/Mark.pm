#!/usr/bin/perl

package KiokuDB::GC::Naive::Mark;
use Moose;

use namespace::clean -except => 'meta';

with 'KiokuDB::Role::Scan' => { result_class => "KiokuDB::GC::Naive::Mark::Results" };

{
    package KiokuDB::GC::Naive::Mark::Results;
    use Moose;

    use Set::Object;

    has [qw(seen root)] => (
        isa => "Set::Object",
        is  => "ro",
        default => sub { Set::Object->new },
    );

    __PACKAGE__->meta->make_immutable;
}

has '+scan_all' => ( default => 0 );

has chunk_size => (
    isa => "Int",
    is  => "ro",
    default => 100,
);

sub process_block {
    my ( $self, %args ) = @_;

    my ( $block, $res ) = @args{qw(block results)};

    my ( $seen, $root ) = map { $res->$_ } qw(seen root);

    my ( $backend, $chunk_size ) = ( $self->backend, $self->chunk_size );

    $root->insert(map { $_->id } @$block);
    @$block = grep { not $seen->includes($_->id) } @$block;

    $seen->insert(map { $_->id } @$block);

    my @queue;

    # recursively walk the entries making note of all seen entries
    loop: {
        foreach my $entry ( @$block ) {
            croak("ERROR: Missing entry. Run FSCK") unless $entry;

            my $id = $entry->id;

            my @candidates = grep { not $seen->includes($_) } $entry->referenced_ids;

            # even though we technically haven't seen them yet, insert into the
            # set so that we scan less data
            $seen->insert(@candidates);

            push @queue, @candidates;
        }

        if ( @queue ) {
            my @ids = ( @queue > $chunk_size ) ? ( splice @queue, -$chunk_size ) : splice @queue;

            # reuse the block array so that we throw away unnecessary data
            @$block = $backend->get(@ids);

            redo loop;
        }
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

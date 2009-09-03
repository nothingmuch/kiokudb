#!/usr/bin/perl

package KiokuDB::Test::Fixture::TXN::Nested;
use Moose;

use Test::More;
use Test::Exception;
use Try::Tiny;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Test::Fixture::TXN);

use constant required_backend_roles => qw(TXN TXN::Nested);

sub sort { 151 } # after TXN

sub verify {
    my $self = shift;

    my $l = $self->directory->live_objects;

    {
        {
            my $s = $self->new_scope;

            my $joe = $self->lookup_ok( $self->joe );

            is( $joe->name, "joe", "name attr" );

            my $entry = $l->objects_to_entries($joe);

            isa_ok( $entry, "KiokuDB::Entry" );

            throws_ok {
                $self->txn_do(sub {
                    $joe->name("lalalala");
                    $self->update_ok($joe);

                    my ( $db_entry ) = $self->backend->get( $self->joe );
                    is( $db_entry->data->{name}, "lalalala", "entry written to DB" );

                    try {
                        $self->txn_do(sub {
                            $joe->name("oi");
                            $self->update_ok($joe);

                            my ( $inner_db_entry ) = $self->backend->get( $self->joe );
                            is( $inner_db_entry->data->{name}, "oi", "entry written to DB" );

                            my $updated_entry = $l->objects_to_entries($joe);

                            isnt( $updated_entry, $entry, "entry updated" );
                            is( $updated_entry->prev->prev, $entry, "parent of parent of updated is orig" );

                            die "foo";
                        });
                    };

                    my ( $db_entry_rolled_back ) = $self->backend->get( $self->joe );
                    is( $db_entry_rolled_back->data->{name}, "lalalala", "rolled back nested txn" );

                    die $@;
                });
            } qr/foo/, "failed transaction";

            my $updated_entry = $l->objects_to_entries($joe);

            is( $updated_entry, $entry, "entry rolled back" );

            is( $joe->name, "oi", "name attr of object" );

            undef $joe;
        }

        $self->no_live_objects;

        {
            my $s = $self->new_scope;

            my $joe = $self->lookup_ok( $self->joe );

            is( $joe->name, "joe", "name rolled back in DB" );

            undef $joe;
        }

        $self->no_live_objects;
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

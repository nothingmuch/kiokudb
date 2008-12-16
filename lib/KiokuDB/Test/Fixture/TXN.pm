#!/usr/bin/perl

package KiokuDB::Test::Fixture::TXN;
use Moose;

use Test::More;
use Test::Exception;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Test::Fixture::Small);

use constant required_backend_roles => qw(TXN);

sub sort { 100 }

sub verify {
    my $self = shift;

    my $l = $self->directory->live_objects;

    {
        my $s = $self->new_scope;

        my $joe = $self->lookup_ok( $self->joe );

        is( $joe->name, "joe", "name attr" );

        my $entry = $l->objects_to_entries($joe);

        isa_ok( $entry, "KiokuDB::Entry" );

        lives_ok {
            $self->txn_do(sub {
                $joe->name("HALLO");
                $self->update_ok($joe);
                my $updated_entry = $l->objects_to_entries($joe);

                isnt( $updated_entry, $entry, "entry updated" );
                is( $updated_entry->prev, $entry, "parent of updated is orig" );
            });
        } "successful transaction";

        my $updated_entry = $l->objects_to_entries($joe);

        isnt( $updated_entry, $entry, "entry updated" );
        is( $updated_entry->prev, $entry, "parent of updated is orig" );

        is( $joe->name, "HALLO", "name attr" );

        undef $joe;
    }

    $self->no_live_objects;

    {
        {
            my $s = $self->new_scope;

            my $joe = $self->lookup_ok( $self->joe );

            my $entry = $l->objects_to_entries($joe);

            isa_ok( $entry, "KiokuDB::Entry" );

            throws_ok {
                $self->txn_do(sub {
                    $joe->name("YASE");
                    $self->update_ok($joe);

                    my $updated_entry = $l->objects_to_entries($joe);

                    isnt( $updated_entry, $entry, "entry updated" );
                    is( $updated_entry->prev, $entry, "parent of updated is orig" );

                    die "foo";
                });
            } qr/foo/, "failed transaction";

            my $updated_entry = $l->objects_to_entries($joe);

            is( $updated_entry, $entry, "entry rolled back" );

            is( $joe->name, "YASE", "name not rolled back in live object" );

            undef $joe;
        }

        $self->no_live_objects;

        {
            my $s = $self->new_scope;

            my $joe = $self->lookup_ok( $self->joe );
            
            is( $joe->name, "HALLO", "name rolled back in DB" );

            undef $joe;
        }

        $self->no_live_objects;

    }

    {
        {
            my $s = $self->new_scope;

            my $joe = $self->lookup_ok( $self->joe );

            is( $joe->name, "HALLO", "name attr" );

            my $entry = $l->objects_to_entries($joe);

            isa_ok( $entry, "KiokuDB::Entry" );

            throws_ok {
                $self->txn_do(sub {
                    $joe->name("lalalala");
                    $self->update_ok($joe);
                    $self->txn_do(sub {
                        $joe->name("oi");
                        $self->update_ok($joe);

                        my $updated_entry = $l->objects_to_entries($joe);

                        isnt( $updated_entry, $entry, "entry updated" );
                        is( $updated_entry->prev->prev, $entry, "parent of parent of updated is orig" );

                        die "foo";
                    });
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

            is( $joe->name, "HALLO", "name rolled back in DB" );

            undef $joe;
        }

        $self->no_live_objects;
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

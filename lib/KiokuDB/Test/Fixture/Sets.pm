package KiokuDB::Test::Fixture::Sets;
use Moose;

use Test::More;
use Scalar::Util qw(weaken);

use KiokuDB::Set::Transient;
use KiokuDB::Set::Deferred;

use KiokuDB::Test::Person;

use namespace::clean -except => "meta";

with qw(KiokuDB::Test::Fixture);

sub create {
    map { KiokuDB::Test::Person->new( name => $_ ) } qw(jemima elvis norton);
}

sub verify {
    my $self = shift;

    my @ids = @{ $self->populate_ids };

    {
        my $s = $self->new_scope;

        my @people = $self->lookup_ok(@ids);

        my $set = KiokuDB::Set::Transient->new( set => Set::Object->new );

        is_deeply([ $set->members ], [], "no members");

        $set->insert($people[0]);

        is_deeply(
            [ $set->members ],
            [ $people[0] ],
            "set members",
        );

        ok( $set->loaded, "set is loaded" );

        $set->insert( $people[0] );

        is( $set->size, 1, "inserting ID of live object already in set did not affect set size" );

        ok( $set->loaded, "set still loaded" );

        $set->insert( $people[2] );

        is( $set->size, 2, "inserting ID of live object" );

        ok( $set->loaded, "set still loaded" );

        is_deeply(
            [ sort $set->members ],
            [ sort @people[0, 2] ],
            "members",
        );

        $set->remove( $people[2] );

        is( $set->size, 1, "removed element" );

        can_ok( $set, "union" );

        foreach my $other ( Set::Object->new( $people[2] ), KiokuDB::Set::Transient->new( set => Set::Object->new( $people[2] ) ) ) {
            my $union = $set->union($other);

            isa_ok( $union, "KiokuDB::Set::Transient", "union" );

            is_deeply(
                [ sort $union->members ],
                [ sort @people[0, 2] ],
                "members",
            );
        }
    }


    {
        my $s = $self->new_scope;

        my $set = KiokuDB::Set::Deferred->new( set => Set::Object->new($ids[0]), _linker => $self->directory->linker );

        ok( !$set->loaded, "set not loaded" );

        is_deeply(
            [ $set->members ],
            [ $self->lookup_ok($ids[0]) ],
            "set vivified",
        );

        ok( $set->loaded, "now marked as loaded" );

        my @people = $self->lookup_ok(@ids);

        foreach my $other ( Set::Object->new( $people[2] ), KiokuDB::Set::Transient->new( set => Set::Object->new( $people[2] ) ) ) {
            my $union = $set->union($other);

            isa_ok( $union, "KiokuDB::Set::Loaded", "union" );

            is_deeply(
                [ sort $union->members ],
                [ sort @people[0, 2] ],
                "members",
            );
        }
    }

    {
        my $s = $self->new_scope;

        my $set = KiokuDB::Set::Deferred->new( _linker => $self->directory->linker );

        is( $set->size, 0, "set size is 0" );

        is_deeply([ $set->members ], [], "no members" );

        is( ref($set), "KiokuDB::Set::Deferred", 'calling members on empty set does not load it' );

        $set->insert($self->lookup_ok(@ids));

        ok( !$set->loaded, "set not loaded by insertion of live objects" );

        $set->remove( $self->lookup_ok($ids[0]) );

        is( $set->size, ( @ids - 1 ), "removed element" );
        ok( !$set->loaded, "set not loaded" );

        my $other = KiokuDB::Set::Deferred->new( set => Set::Object->new($ids[0]), _linker => $self->directory->linker );

        isa_ok( my $union = $set->union($other), "KiokuDB::Set::Deferred" );

        ok( !$union->loaded, "union is deferred" );

        is_deeply(
            [ sort $set->members ],
            [ sort $self->lookup_ok(@ids[1, 2]) ],
            "members",
        );

        ok( $set->loaded, "now it is loaded" );

        is_deeply(
            [ sort $union->members ],
            [ sort $self->lookup_ok(@ids[0, 1, 2]) ],
            "union",
        );
    }

    $self->no_live_objects;

    {
        my $s = $self->new_scope;

        my $set = KiokuDB::Set::Deferred->new( _linker => $self->directory->linker );

        is_deeply([ $set->members ], [], "no members");

        $set->_objects->insert(@ids);

        ok( !$set->loaded, "set not loaded" );

        $set->clear;

        is( $set->size, 0, "cleared" );

        ok( $set->loaded, "cleared set is loaded" );
    }

    $self->no_live_objects;

    my $set_id = do {
        my $s = $self->new_scope;

        my @people = $self->lookup_ok(@ids);

        $self->store_ok( KiokuDB::Set::Transient->new( set => Set::Object->new($people[0]) ) );
    };

    $self->no_live_objects;

    {
        my $s = $self->new_scope;

        my $set = $self->lookup_ok($set_id);

        isa_ok( $set, "KiokuDB::Set::Deferred", "deferred set" );

        is( $set->size, 1, "set size" );

        is_deeply(
            [ $set->members ],
            [ $self->lookup_ok($ids[0]) ],
            "members",
        );

        ok( $set->loaded, "loaded set" );
    }

    $self->no_live_objects;

    {
        my $s = $self->new_scope;

        my $set = $self->lookup_ok($set_id);

        isa_ok( $set, "KiokuDB::Set::Deferred", "deferred set" );

        is( $set->size, 1, "set size" );

        $set->insert( $self->lookup_ok($ids[2]) );

        is( $set->size, 2, "set size is 2");

        ok( !$set->loaded, "set not loaded" );

        $self->store_ok($set);

        ok( !$set->loaded, "set not loaded by ->store" );
    }

    $self->no_live_objects;

    {
        my $s = $self->new_scope;

        my $set = $self->lookup_ok($set_id);

        isa_ok( $set, "KiokuDB::Set::Deferred", "deferred set" );

        is( $set->size, 2, "set size" );

        is_deeply(
            [ sort $set->members ],
            [ sort $self->lookup_ok(@ids[0, 2]) ],
            "members",
        );

        ok( $set->loaded, "loaded set" );
    }

    $self->no_live_objects;
}

__PACKAGE__->meta->make_immutable;

# ex: set sw=4 et:

__PACKAGE__

__END__


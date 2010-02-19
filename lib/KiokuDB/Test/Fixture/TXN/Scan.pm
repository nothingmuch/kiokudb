package KiokuDB::Test::Fixture::TXN::Scan;
use Moose;

use Test::More;
use Test::Exception;
use Test::Moose;

use KiokuDB::Test::Person;

use namespace::clean -except => 'meta';

extends qw(KiokuDB::Test::Fixture::Scan);

override required_backend_roles => sub {
    return (qw(TXN), super());
};

sub sort { 151 }

around populate => sub {
    my ( $next, $self, @args ) = @_;

    $self->txn_do(sub { $self->$next(@args) });
};

sub verify {
    my $self = shift;

    $self->txn_lives(sub {
        my $root = $self->root_set;

        does_ok( $root, "Data::Stream::Bulk" );

        my @objs = $root->all;

        my @ids = $self->objects_to_ids(@objs);

        is_deeply(
            [ sort map { $_->name } @objs ],
            [ sort qw(foo bar gorch) ],
            "root set",
        );

        is_deeply(
            [ sort $self->backend->root_entry_ids->all ],
            [ sort @ids ],
            "root set IDs",
        );
    });

    throws_ok {
        $self->txn_do(scope => 1, body => sub {
            $self->insert_ok( KiokuDB::Test::Person->new( name => "another" ) );

            my $root = $self->root_set;

            does_ok( $root, "Data::Stream::Bulk" );

            my @objs = $root->all;

            my @ids = $self->objects_to_ids(@objs);

            is_deeply(
                [ sort map { $_->name } @objs ],
                [ sort qw(foo bar gorch another) ],
                "root set reflects insertion",
            );

            is_deeply(
                [ sort $self->backend->root_entry_ids->all ],
                [ sort @ids ],
                "root set IDs are the same",
            );

            die "rollback";
        });
    } qr/rollback/;

    $self->txn_lives(sub {
        my $root = $self->root_set;

        my @objs = $root->all;

        my @ids = $self->objects_to_ids(@objs);

        is_deeply(
            [ sort map { $_->name } @objs ],
            [ sort qw(foo bar gorch) ],
            "root set rolled back",
        );

        is_deeply(
            [ sort $self->backend->root_entry_ids->all ],
            [ sort @ids ],
            "ids are the same",
        );
    });

    my $foo_id;
    $self->txn_lives(sub {
        my %objs = map { $_->name => $_ } $self->root_set->all;
        $foo_id = $self->object_to_id($objs{foo});
    });

    ok( defined($foo_id), "got an ID for foo" );

    throws_ok {
        $self->txn_do(scope => 1, body => sub {
            $self->delete_ok($foo_id);

            {
                my $root = $self->root_set;

                my @objs = $root->all;

                my @ids = $self->objects_to_ids(@objs);

                is_deeply(
                    [ sort map { $_->name } @objs ],
                    [ sort qw(bar gorch) ],
                    "root set reflects deletion",
                );

                is_deeply(
                    [ sort $self->backend->root_entry_ids->all ],
                    [ sort @ids ],
                    "root set IDs are the same",
                );
            }

            {
                $self->insert_ok( KiokuDB::Test::Person->new( name => "blah" ) );

                my $root = $self->root_set;

                does_ok( $root, "Data::Stream::Bulk" );

                my @objs = $root->all;

                my @ids = $self->objects_to_ids(@objs);

                is_deeply(
                    [ sort map { $_->name } @objs ],
                    [ sort qw(blah bar gorch) ],
                    "root set reflects deletion and insertion",
                );

                is_deeply(
                    [ sort $self->backend->root_entry_ids->all ],
                    [ sort @ids ],
                    "root set IDs are the same",
                );
            }

            die "rollback";
        });
    } qr/rollback/;

    $self->txn_lives(sub {
        my $root = $self->root_set;

        my @objs = $root->all;

        my @ids = $self->objects_to_ids(@objs);

        is_deeply(
            [ sort map { $_->name } @objs ],
            [ sort qw(foo bar gorch) ],
            "root set",
        );

        is_deeply(
            [ sort $self->backend->root_entry_ids->all ],
            [ sort @ids ],
            "ids are the same",
        );
    });

    $self->txn_lives(sub {
        my @objs = $self->all_objects->all;

        my @ids = $self->objects_to_ids(@objs);

        is_deeply(
            [ sort map { $_->name } @objs ],
            [ sort qw(foo bar gorch quxx) ],
            "all entries",
        );

        is_deeply(
            [ sort $self->backend->all_entry_ids->all ],
            [ sort @ids ],
            "all IDs",
        );
    });

    throws_ok {
        $self->txn_do(scope => 1, body => sub {
            $self->backend->clear;

            is_deeply(
                [ $self->all_objects->all ],
                [ ],
                "no enrtries (db cleared)",
            );

            $self->insert_ok( KiokuDB::Test::Person->new( name => "very new" ) );

            is_deeply(
                [ map { $_->name } $self->all_objects->all ],
                [ "very new" ],
                "one entry",
            );

            $self->txn_lives(sub {
                $self->backend->clear;

                is_deeply(
                    [ $self->all_objects->all ],
                    [ ],
                    "no enrtries (db cleared)",
                );
            });

            is_deeply(
                [ $self->all_objects->all ],
                [ ],
                "no enrtries (db cleared)",
            );

            die "rollback";
        });
    } qr/rollback/, "rolled back";

    $self->txn_lives(sub {
        my @objs = $self->all_objects->all;

        my @ids = $self->objects_to_ids(@objs);

        is_deeply(
            [ sort map { $_->name } @objs ],
            [ sort qw(foo bar gorch quxx) ],
            "all entries restored",
        );

        is_deeply(
            [ sort $self->backend->all_entry_ids->all ],
            [ sort @ids ],
            "all IDs",
        );
    });

    $self->txn_lives(sub {
        $self->backend->clear;
    });

    $self->txn_lives(sub {
        is_deeply(
            [ $self->all_objects->all ],
            [ ],
            "no enrtries (db cleared)",
        );
    });
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__


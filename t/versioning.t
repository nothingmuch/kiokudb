#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use KiokuDB;

{
    package VersionedPerson;
    use Moose;

    extends qw(KiokuDB::Test::Person);

    with qw(KiokuDB::Role::Upgrade::Handlers::Table);

    use constant kiokudb_upgrade_handlers_table => {

        # like the individual entries in class_version_table

        "0.01" => "0.02",
        "0.02" => sub {
            my ( $class, %args ) = @_;

            $args{entry}->derive(
                class_version => "0.03",
                data => {
                    %{ $args{entry}->data },
                    name => "new name",
                },
            );
        },
    };
}

foreach my $format ( qw(memory storable json), eval { require YAML::XS; "yaml" } ) {
    my $dir = KiokuDB->connect("hash",
        check_class_versions => 1,
        serializer           => $format,
    );

    local $VersionedPerson::VERSION = "0.01";

    $dir->txn_do( scope => 1, body => sub {
        my $p = VersionedPerson->new(
            name => "blah blah",
        );

        $dir->insert( person => $p );

        is( $dir->live_objects->object_to_entry($p)->class_version, $VersionedPerson::VERSION, "Class version set" );
    });

    $dir->typemap_resolver->clear_compiled;
    KiokuDB::TypeMap::Entry::MOP->clear_version_cache;

    $dir->txn_do( scope => 1, body => sub {
        my $p = $dir->lookup("person");

        is( $p->name, "blah blah", "no upgrade" );

        is( $dir->live_objects->object_to_entry($p)->class_version, $VersionedPerson::VERSION, "Class version set" );

        $dir->update($p);
    });

    $dir->typemap_resolver->clear_compiled;
    KiokuDB::TypeMap::Entry::MOP->clear_version_cache;

    local $VersionedPerson::VERSION = "0.02";

    $dir->txn_do( scope => 1, body => sub {
        my $p = $dir->lookup("person");

        is( $p->name, "blah blah", "upgrade to 0.02 is noop" );

        is( $dir->live_objects->object_to_entry($p)->class_version, "0.01", "Class version not changed due to noop" );

        $dir->update($p);
    });

    $dir->typemap_resolver->clear_compiled;
    KiokuDB::TypeMap::Entry::MOP->clear_version_cache;

    $dir->txn_do( scope => 1, body => sub {
        my $p = $dir->lookup("person");

        is( $p->name, "blah blah", "upgrade to 0.02 is noop" );

        is( $dir->live_objects->object_to_entry($p)->class_version, $VersionedPerson::VERSION, "Class version updated in storage" );
    });

    $dir->typemap_resolver->clear_compiled;
    KiokuDB::TypeMap::Entry::MOP->clear_version_cache;

    local $VersionedPerson::VERSION = "0.03";

    $dir->txn_do( scope => 1, body => sub {
        my $p = $dir->lookup("person");

        is( $p->name, "new name", "class upgraded to 0.03" );

        is( $dir->live_objects->object_to_entry($p)->class_version, $VersionedPerson::VERSION, "Class version set" );

        $p->name("foobar");

        $dir->update($p);
    });

    $dir->typemap_resolver->clear_compiled;
    KiokuDB::TypeMap::Entry::MOP->clear_version_cache;

    $dir->txn_do( scope => 1, body => sub {
        my $p = $dir->lookup("person");

        is( $p->name, "foobar", "upgrade handler did not fire twice" );

        is( $dir->live_objects->object_to_entry($p)->class_version, $VersionedPerson::VERSION, "Class version set" );

        $dir->update($p);
    });

    $dir->typemap_resolver->clear_compiled;
    KiokuDB::TypeMap::Entry::MOP->clear_version_cache;

    local $VersionedPerson::VERSION = "0.04";

    throws_ok {
        $dir->txn_do( scope => 1, body => sub {
            $dir->lookup("person");
        });
    } qr/0\.03/, "no handler for 0.03";

    KiokuDB::TypeMap::Entry::MOP->clear_version_cache;
}

done_testing;

# ex: set sw=4 et:


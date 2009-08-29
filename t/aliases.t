#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 8;

use ok 'KiokuDB::Alias';
use ok 'KiokuDB';

use ok 'KiokuDB::Test::Person';

my $dir = KiokuDB->connect("hash");

{
    my $s = $dir->new_scope;

    my $p = KiokuDB::Test::Person->new( name => "foo" );

    my $a = KiokuDB::Alias->new( target => $p );

    $dir->insert( foo => $a );

    is( $dir->lookup("foo"), $p, "alias resolved" );
}

{
    my $s = $dir->new_scope;

    my $p = $dir->lookup("foo");

    isa_ok( $p, "KiokuDB::Test::Person", "resolved on load" );

    my $a = $dir->id_to_object("foo");

    isa_ok( $a, "KiokuDB::Alias" );

    is( $a->target, $p, "alias target" );

    $dir->insert( "bar", KiokuDB::Alias->new( target => $a ) );

    is( $dir->lookup("bar"), $p, "resolved recursively" );
}

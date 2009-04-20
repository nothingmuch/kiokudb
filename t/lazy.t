#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Moose;
use Test::Exception;

use ok 'KiokuDB';
use ok 'KiokuDB::Backend::Hash';

{
    package Simple;
    use KiokuDB::Class;

    has name => ( is => "rw" );

    has foo => (
        traits => [qw(KiokuDB::Lazy)],
        isa    => __PACKAGE__,
        is     => "ro",
    );

    has foos => (
        traits => [qw(KiokuDB::Lazy)],
        isa    => 'ArrayRef',
        is     => "ro",
    );
}

ok( exists($INC{"KiokuDB/Meta/Attribute/Lazy.pm"}), "KiokuDB::Meta::Attribute::Lazy loaded" );

does_ok( Simple->meta->get_attribute("foo"), 'KiokuDB::Meta::Attribute::Lazy', '"foo" meta attr does KiokuDB::Meta::Attribute::Lazy' );
does_ok( Simple->meta->get_attribute("foos"), 'KiokuDB::Meta::Attribute::Lazy', '"foo" meta attr does KiokuDB::Meta::Attribute::Lazy' );

my $dir = KiokuDB->new( backend => KiokuDB::Backend::Hash->new );

{
    my $s = $dir->new_scope;

    my ( $foo, @baz ) = map { Simple->new } 1 .. 3;
    my $bar = Simple->new( foo => $foo, foos => \@baz);

    is( $bar->foo, $foo, "foo attribute" );

    $dir->store( foo => $foo, bar => $bar );
}

{
    my $s = $dir->new_scope;

    is_deeply(
        [ $dir->live_objects->live_objects ],
        [],
        "no live objects",
    );

    my $bar = $dir->lookup("bar");

    is_deeply(
        [ $dir->live_objects->live_objects ],
        [ $bar ],
        "only bar is live",
    );

    my $foos = $bar->foos;

    is_deeply(
        [ sort $dir->live_objects->live_objects ],
        [ sort @$foos, $bar ],
        "all objects are live",
    );
}

{
    my $s = $dir->new_scope;

    is_deeply(
        [ $dir->live_objects->live_objects ],
        [],
        "no live objects",
    );

    my $bar = $dir->lookup("bar");

    is_deeply(
        [ $dir->live_objects->live_objects ],
        [ $bar ],
        "only bar is live",
    );

    my $foo = $bar->foo;

    is_deeply(
        [ sort $dir->live_objects->live_objects ],
        [ sort $foo, $bar ],
        "both objects are live",
    );
}

{
    my $s = $dir->new_scope;

    is_deeply(
        [ $dir->live_objects->live_objects ],
        [],
        "no live objects",
    );

    my $bar = $dir->lookup("bar");

    is_deeply(
        [ $dir->live_objects->live_objects ],
        [ $bar ],
        "only bar is live",
    );

    $bar->name("moose");

    $dir->update($bar);

    is_deeply(
        [ $dir->live_objects->live_objects ],
        [ $bar ],
        "only bar is live",
    );
}

{
    my $s = $dir->new_scope;

    is_deeply(
        [ $dir->live_objects->live_objects ],
        [],
        "no live objects",
    );

    my $bar = $dir->lookup("bar");

    is( $bar->name, "moose", "name updated" );

    is_deeply(
        [ $dir->live_objects->live_objects ],
        [ $bar ],
        "only bar is live",
    );

    my $foo = $bar->foo;

    is_deeply(
        [ sort $dir->live_objects->live_objects ],
        [ sort $foo, $bar ],
        "both objects are live",
    );
}


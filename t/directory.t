#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::TempDir;

use ok 'MooseX::Storage::Directory';
use ok 'MooseX::Storage::Directory::Backend::JSPON';

my $dir = MooseX::Storage::Directory->new(
	backend => MooseX::Storage::Directory::Backend::JSPON->new(
		dir => temp_root,
	),
);

{
    package Foo;
    use Moose;

    has foo => (
        isa => "Str",
        is  => "rw",
    );

    has bar => (
        is => "rw",
    );
}

# Pixie ain't got nuthin on us
my $id = do {
    my $x = Foo->new(
        foo => "dancing",
        bar => Foo->new(
            foo => "oh",
        ),
    );

    $x->bar->bar($x);

    $dir->store($x);
};

{
    my $obj = $dir->lookup($id);

    is( $obj->foo, "dancing", "simple attr" );
    isa_ok( $obj->bar, "Foo", "object attr" );
    is( $obj->bar->foo, "oh", "simple attr of sub object" );
    isa_ok( $obj->bar->bar, "Foo", "object attr of sub object" );
    is( $obj->bar->bar, $obj, "circular ref" );
}

{
    my $x = Foo->new(
        foo => "oink oink",
        bar => my $y = Foo->new(
            foo => "yay",
        ),
    );

    my @ids = $dir->store($x, $y);

    is( scalar(@ids), 2, "got two ids" );

    undef $x;

    is( $dir->live_objects->id_to_object($ids[0]), undef, "first object is dead" );
    is( $dir->live_objects->id_to_object($ids[1]), $y, "second is still alive" );

    my @objects = map { $dir->lookup($_) } @ids;
    
    isa_ok( $objects[0], "Foo" );
    is( $objects[0]->foo, "oink oink", "object retrieved" );
    is( $objects[1], $y, "object is already live" );
    is( $objects[0]->bar, $y, "link recreated" );
}

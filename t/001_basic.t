#!/usr/bin/perl

use strict;
use warnings;

use Test::More no_plan => 1;
use Test::Exception;
use Test::Moose;

BEGIN {
    use_ok('MooseX::Storage::Directory');
    use_ok('MooseX::Storage::Directory::WithUUID');
}

{
    package Foo;
    use Moose;
    use MooseX::Storage;
    
    with 'MooseX::Storage::Directory::WithUUID', 
         Storage(
             'format' => 'JSON', 
             'io'     => 'File',
         );
    
    has 'bar' => (
        is      => 'rw',
        isa     => 'Str',   
        default => sub { 'Foo::bar' },
    );
    
    package Bar;
    use Moose;
    
    extends 'Foo';
    
    has 'baz' => (
        is      => 'ro',
        isa     => 'Str',   
        default => sub { 'Foo::baz' },
    );
}

my $DIR_NAME = 'temp';

my $dir = MooseX::Storage::Directory->new(dir => [ $DIR_NAME ]);
isa_ok($dir, 'MooseX::Storage::Directory');

$dir->setup;

my $foo = Foo->new;
isa_ok($foo, 'Foo');
does_ok($foo, 'MooseX::Storage::Directory::WithUUID');
does_ok($foo, 'MooseX::Storage::Format::JSON');
does_ok($foo, 'MooseX::Storage::IO::File');
does_ok($foo, 'MooseX::Storage::Basic');

my $uuid = $dir->store(object => $foo);

my $bar = Bar->new;
isa_ok($bar, 'Bar');
isa_ok($bar, 'Foo');

$dir->store(object => $bar);

## foo2

my $foo2 = $dir->load(class => 'Foo', uuid => $uuid);
isa_ok($foo2, 'Foo');

isnt($foo, $foo2, '... these objects are not equal');

is($foo->uuid, $foo2->uuid, '... these objects uuids are equal');
is($foo->bar, $foo2->bar, '... these objects foos are equal');

$foo2->bar('Foo::bar2');

$dir->store(object => $foo2);

## foo3

my $foo3 = $dir->load(class => 'Foo', uuid => $uuid);
isa_ok($foo3, 'Foo');

isnt($foo, $foo3, '... these objects are not equal');
isnt($foo2, $foo3, '... these objects are not equal');

is($foo->uuid, $foo3->uuid, '... these objects uuids are equal');
is($foo2->uuid, $foo3->uuid, '... these objects uuids are equal');

isnt($foo->bar, $foo2->bar, '... these objects foos are not equal');
is($foo2->bar, $foo3->bar, '... these objects foos are equal');

system("rm -rf " . $dir->dir);





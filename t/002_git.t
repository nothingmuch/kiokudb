#!/usr/bin/perl

use Test::More tests => 2;

{

    package Foo;
    use Moose;
    use MooseX::Storage;

    with 'MooseX::Storage::Directory::WithUUID',
      Storage(
        'format' => 'YAML',
        'io'     => 'File',
      );

    has 'count' => (
        is      => 'rw',
        isa     => 'Int',
        default => 1,
    );
}

use MooseX::Storage::Directory::Git;

my $dir = MooseX::Storage::Directory::Git->new( dir => ['tmp/'], branch => 'master' );

$dir->setup;

my $foo = Foo->new;

my $uuid = $dir->store( object => $foo, message => 'one' );
$foo->count(2);
$uuid = $dir->store( object => $foo, message => 'two' );
$foo->count(3);
$uuid = $dir->store( object => $foo, message => 'three' );

my $foo2 = $dir->load( class => 'Foo', uuid => $uuid, checkout => 'master~2' );

is($foo2->count, 1, 'First commit');

my $foo3 = $dir->load( class => 'Foo', uuid => $uuid, checkout => 'master' );
is($foo3->count, 3, 'Latest commit');

system("rm -rf " . $dir->dir);

#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Data::Stream::Bulk::Callback;

use ok 'KiokuDB';
use ok 'KiokuDB::Backend::Hash';
use_ok 'KiokuDB::Stream::Objects';

{
    package KiokuDB_Test_Foo;
    use Moose;

    has id  => (is => 'rw', isa => 'Str');
    has num => (is => 'rw', isa => 'Int');
}

my $dir = KiokuDB->connect( "hash", serializer => 'memory');

my @objs = (
    KiokuDB_Test_Foo->new( id => 'one',   num => 1 ),
    KiokuDB_Test_Foo->new( id => 'two',   num => 2 ),
    KiokuDB_Test_Foo->new( id => 'three', num => 3 ),
    KiokuDB_Test_Foo->new( id => 'zero',  num => 0 ),
    KiokuDB_Test_Foo->new( id => 'four',  num => 4 ),
);

{
    my $s = $dir->new_scope;

    foreach my $obj (@objs) {
        lives_ok { $dir->store( $obj->id   => $obj ) } "can store " . $obj->id;
    }
}

my @ids = $dir->store(@objs);

sub iter {
    my @x = @objs;
    Data::Stream::Bulk::Callback->new(
    callback =>
    sub { return unless @x; return [ shift @x ] })->filter(sub {[grep { $_->num } @$_ ]});
}

is_deeply([map { $_->num } iter()->all],[1,2,3,4], "found 4 objects");

my $stream =KiokuDB::Stream::Objects ->new(
  directory => $dir,
  entry_stream => iter(),
);

is_deeply([map { $_->num } $stream->all],[1,2,3,4], "found 4 objects");

done_testing;

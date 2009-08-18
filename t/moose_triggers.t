#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use KiokuDB;

{
    package Bar;
    use Moose;

    package Foo;
    use KiokuDB::Class;

    has 'bar' => (
        traits  => [ 'KiokuDB::Lazy' ],
        is      => 'rw',
        isa     => 'Bar',
		trigger => sub { } # doesnt need to do anything, just exist
    );
}

my $dir = KiokuDB->connect("hash");

$dir->txn_do(scope => 1, body => sub {
	$dir->store( foo => Foo->new( bar => Bar->new ) );
});

$dir->txn_do(scope => 1, body => sub {
    my $foo = $dir->lookup("foo");
    isa_ok($foo, 'Foo');

	lives_ok {
		local $SIG{ALRM} = sub { die "timed out" };
        local $SIG{__WARN__} = sub { die "warnings" };
		alarm 1;
		$foo->bar( Bar->new );
		alarm 0;
	} "successfully set a new value for the 'bar' attribute";
});

done_testing();

#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use KiokuDB;

{
    package KiokuDB_Test_Bar;
    use Moose;

    package KiokuDB_Test_Foo;
    use KiokuDB::Class;

    has 'bar' => (
        traits  => [ 'KiokuDB::Lazy' ],
        is      => 'rw',
        isa     => 'KiokuDB_Test_Bar',
		trigger => sub { } # doesnt need to do anything, just exist
    );
}

my $dir = KiokuDB->connect("hash");

$dir->txn_do(scope => 1, body => sub {
	$dir->store( foo => KiokuDB_Test_Foo->new( bar => KiokuDB_Test_Bar->new ) );
});

$dir->txn_do(scope => 1, body => sub {
    my $foo = $dir->lookup("foo");
    isa_ok($foo, 'KiokuDB_Test_Foo');

	lives_ok {
		local $SIG{ALRM} = sub { die "timed out" };
        local $SIG{__WARN__} = sub { die @_ if $_[0] =~ /recursion/i; warn @_ };
		alarm 1;
		$foo->bar( KiokuDB_Test_Bar->new );
		alarm 0;
	} "successfully set a new value for the 'bar' attribute";
});

done_testing();

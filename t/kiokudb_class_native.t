#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Exception;

{
    package Foo;
    use KiokuDB::Class;

    ::lives_ok {
        has bad_attribute => (
            traits  => [ qw(String) ],
            is      => 'rw',
            isa     => 'Str',
            default => q{},
            handles => {
                add_comment => 'append',
            },
        );
    } "native traits inline properly";
}

done_testing;

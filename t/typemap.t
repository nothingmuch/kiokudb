#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Moose;
use Test::Exception;

use ok 'KiokuDB::TypeMap';
use ok 'KiokuDB::TypeMap::Entry::Alias';
use ok 'KiokuDB::TypeMap::Entry::Naive';

{
    package Foo;
    use Moose;

    package Bar;
    use Moose;

    extends qw(Foo);

    package CA;
    use base qw(Class::Accessor);

    package CA::Sub;
    use base qw(CA);
}

{
    my $n = KiokuDB::TypeMap::Entry::Naive->new;

    isa_ok( $n, "KiokuDB::TypeMap::Entry::Naive" );
    does_ok( $n, "KiokuDB::TypeMap::Entry" );

    my $t = KiokuDB::TypeMap->new(
        entries => {
            CA => $n,
        }
    );

    isa_ok( $t, "KiokuDB::TypeMap" );

    is( $t->resolve("CA"), $n, "resolve regular entry" );
    is( $t->resolve("CA::Sub"), undef, "failed resolution of subclass" );
    is( $t->resolve("Foo"), undef, "failed resolution of unspecified class" );
    is( $t->resolve("Blarfla"), undef, "failed resolution of random string" );
}

{
    my $n = KiokuDB::TypeMap::Entry::Naive->new;

    my $a = KiokuDB::TypeMap::Entry::Alias->new( to => "CA" );

    isa_ok( $a, "KiokuDB::TypeMap::Entry::Alias" );
    ok( !$a->does("KiokuDB::TypeMap::Entry"), "alias is not a real type entry" );

    my $t = KiokuDB::TypeMap->new(
        entries => {
            CA => $n,
            Foo => $a,
        }
    );

    isa_ok( $t, "KiokuDB::TypeMap" );

    is( $t->resolve("CA"), $n, "resolve regular entry" );
    is( $t->resolve("CA::Sub"), undef, "failed resolution of subclass" );
    is( $t->resolve("Foo"), $n, "alias resolution" );
    is( $t->resolve("Blarfla"), undef, "failed resolution of random string" );
}

{
    my $n = KiokuDB::TypeMap::Entry::Naive->new;

    my $t = KiokuDB::TypeMap->new(
        isa_entries => {
            CA => $n,
        }
    );

    isa_ok( $t, "KiokuDB::TypeMap" );

    is( $t->resolve("CA"), $n, "resolve isa entry for base class" );
    is( $t->resolve("CA::Sub"), $n, "resolve isa entry for subclass" );
    is( $t->resolve("Foo"), undef, "failed resolution" );
}

{
    my $n = KiokuDB::TypeMap::Entry::Naive->new;

    my $t = KiokuDB::TypeMap->new(
        isa_entries => {
            CA => $n,
            Foo => KiokuDB::TypeMap::Entry::Alias->new( to => "CA" ),
        }
    );

    isa_ok( $t, "KiokuDB::TypeMap" );

    is( $t->resolve("CA"), $n, "resolve isa entry for base class" );
    is( $t->resolve("CA::Sub"), $n, "resolve isa entry for subclass" );
    is( $t->resolve("Foo"), $n, "alias resolution of isa entry" );
    is( $t->resolve("Bar"), $n, "alias resolution of isa entry" );
    is( $t->resolve("Blarfla"), undef, "failed resolution of random string" );
}

{
    # typemap inheritence

    my $ca = KiokuDB::TypeMap::Entry::Naive->new;
    my $foo = KiokuDB::TypeMap::Entry::Naive->new;

    my $t1 = KiokuDB::TypeMap->new(
        includes => [
            KiokuDB::TypeMap->new(
                entries => {
                    'CA' => $ca,
                },
            ),
        ],
        entries => {
            'Foo' => $foo,
        }
    );
    
    my $t2 = KiokuDB::TypeMap->new(
        entries => {
            'CA' => $ca,
        },
        includes => [
            KiokuDB::TypeMap->new(
                entries => {
                    'Foo' => $foo,
                }
            ),
        ],
    );

    my $t3 = KiokuDB::TypeMap->new(
        includes => [
            KiokuDB::TypeMap->new(
                entries => {
                    'CA' => $ca,
                },
            ),
            KiokuDB::TypeMap->new(
                entries => {
                    'Foo' => $foo,
                }
            ),
        ],
    );

    my @desc = ( "inherit CA", "inherit Foo", "inherit both" );
    foreach my $t ( $t1, $t2, $t3 ) {
        my $desc = "(". shift(@desc) . ")";

        isa_ok( $t, "KiokuDB::TypeMap" );

        is( $t->resolve("CA"), $ca, "resolve CA entry $desc" );
        is( $t->resolve("Foo"), $foo, "resolve Foo entry $desc" );
        is( $t->resolve("CA::Sub"), undef, "failed resolution $desc" );
        is( $t->resolve("Bar"), undef, "failed resolution $desc" );
    }
}

{
    # typemap inheritence of isa types

    my $ca = KiokuDB::TypeMap::Entry::Naive->new;
    my $foo = KiokuDB::TypeMap::Entry::Naive->new;

    my $t1 = KiokuDB::TypeMap->new(
        includes => [
            KiokuDB::TypeMap->new(
                isa_entries => {
                    'CA' => $ca,
                },
            ),
        ],
        isa_entries => {
            'Foo' => $foo,
        }
    );
    
    my $t2 = KiokuDB::TypeMap->new(
        isa_entries => {
            'CA' => $ca,
        },
        includes => [
            KiokuDB::TypeMap->new(
                isa_entries => {
                    'Foo' => $foo,
                }
            ),
        ],
    );

    my $t3 = KiokuDB::TypeMap->new(
        includes => [
            KiokuDB::TypeMap->new(
                isa_entries => {
                    'CA' => $ca,
                },
            ),
            KiokuDB::TypeMap->new(
                isa_entries => {
                    'Foo' => $foo,
                }
            ),
        ],
    );

    my @desc = ( "inherit CA", "inherit Foo", "inherit both" );
    foreach my $t ( $t1, $t2, $t3 ) {
        my $desc = "(". shift(@desc) . ")";

        isa_ok( $t, "KiokuDB::TypeMap" );

        is_deeply( $t->all_isa_entry_classes, [qw(Foo CA)], "isa entry classes" );

        is( $t->resolve("CA"), $ca, "resolve CA entry $desc" );
        is( $t->resolve("Foo"), $foo, "resolve Foo entry $desc" );
        is( $t->resolve("CA::Sub"), $ca, "resolve CA entry for subclass $desc" );
        is( $t->resolve("Bar"), $foo, "resolve Foo entry for subclass $desc" );
    }
}

{
    # typemap inheritence conflicts

    my $ca = KiokuDB::TypeMap::Entry::Naive->new;

    throws_ok {
        KiokuDB::TypeMap->new(
            entries => {
                'CA' => $ca,
            },
            isa_entries => {
                'CA' => $ca,
            }
        );
    } qr/\bCA\b/, "regular conflicting with isa entry";

}

{
    # typemap inheritence conflicts

    my $ca = KiokuDB::TypeMap::Entry::Naive->new;

    throws_ok {
        KiokuDB::TypeMap->new(
            includes => [
                KiokuDB::TypeMap->new(
                    entries => {
                        'CA' => $ca,
                    },
                ),
                KiokuDB::TypeMap->new(
                    entries => {
                        'CA' => $ca,
                    }
                ),
            ],
        );
    } qr/\bCA\b/, "regular entry conflict";

    throws_ok {
        KiokuDB::TypeMap->new(
            includes => [
                KiokuDB::TypeMap->new(
                    isa_entries => {
                        'CA' => $ca,
                    },
                ),
                KiokuDB::TypeMap->new(
                    isa_entries => {
                        'CA' => $ca,
                    }
                ),
            ],
        );
    } qr/\bCA\b/, "isa entry conflict";

    throws_ok {
        KiokuDB::TypeMap->new(
            includes => [
                KiokuDB::TypeMap->new(
                    isa_entries => {
                        'CA' => $ca,
                    },
                ),
                KiokuDB::TypeMap->new(
                    entries => {
                        'CA' => $ca,
                    }
                ),
            ],
        );
    } qr/\bCA\b/, "mixed entry conflict";
}

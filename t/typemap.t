#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Moose;
use Test::Exception;

use ok 'KiokuDB::TypeMap';
use ok 'KiokuDB::TypeMap::Entry::Alias';
use ok 'KiokuDB::TypeMap::Entry::Naive';

{
    package KiokuDB_Test_Foo;
    use Moose;

    package KiokuDB_Test_Bar;
    use Moose;

    extends qw(KiokuDB_Test_Foo);

    package KiokuDB_Test_CA;

    package KiokuDB_Test_CA::Sub;
    use base qw(KiokuDB_Test_CA);
}

{
    my $n = KiokuDB::TypeMap::Entry::Naive->new;

    isa_ok( $n, "KiokuDB::TypeMap::Entry::Naive" );
    does_ok( $n, "KiokuDB::TypeMap::Entry" );

    my $t = KiokuDB::TypeMap->new(
        entries => {
            KiokuDB_Test_CA => $n,
        }
    );

    isa_ok( $t, "KiokuDB::TypeMap" );

    is( $t->resolve("KiokuDB_Test_CA"), $n, "resolve regular entry" );
    is( $t->resolve("KiokuDB_Test_CA::Sub"), undef, "failed resolution of subclass" );
    is( $t->resolve("KiokuDB_Test_Foo"), undef, "failed resolution of unspecified class" );
    is( $t->resolve("Blarfla"), undef, "failed resolution of random string" );
}

{
    my $n = KiokuDB::TypeMap::Entry::Naive->new;

    my $a = KiokuDB::TypeMap::Entry::Alias->new( to => "KiokuDB_Test_CA" );

    isa_ok( $a, "KiokuDB::TypeMap::Entry::Alias" );
    ok( !$a->does("KiokuDB::TypeMap::Entry"), "alias is not a real type entry" );

    my $t = KiokuDB::TypeMap->new(
        entries => {
            KiokuDB_Test_CA => $n,
            KiokuDB_Test_Foo => $a,
        }
    );

    isa_ok( $t, "KiokuDB::TypeMap" );

    is( $t->resolve("KiokuDB_Test_CA"), $n, "resolve regular entry" );
    is( $t->resolve("KiokuDB_Test_CA::Sub"), undef, "failed resolution of subclass" );
    is( $t->resolve("KiokuDB_Test_Foo"), $n, "alias resolution" );
    is( $t->resolve("Blarfla"), undef, "failed resolution of random string" );
}

{
    my $n = KiokuDB::TypeMap::Entry::Naive->new;

    my $t = KiokuDB::TypeMap->new(
        isa_entries => {
            KiokuDB_Test_CA => $n,
        }
    );

    isa_ok( $t, "KiokuDB::TypeMap" );

    is( $t->resolve("KiokuDB_Test_CA"), $n, "resolve isa entry for base class" );
    is( $t->resolve("KiokuDB_Test_CA::Sub"), $n, "resolve isa entry for subclass" );
    is( $t->resolve("KiokuDB_Test_Foo"), undef, "failed resolution" );
}

{
    my $n = KiokuDB::TypeMap::Entry::Naive->new;

    my $t = KiokuDB::TypeMap->new(
        isa_entries => {
            KiokuDB_Test_CA => $n,
            KiokuDB_Test_Foo => KiokuDB::TypeMap::Entry::Alias->new( to => "KiokuDB_Test_CA" ),
        },
        entries => {
            'Unknown::KiokuDB_Test_Foo' => KiokuDB::TypeMap::Entry::Alias->new( to => "KiokuDB_Test_CA" ),
        },
    );

    isa_ok( $t, "KiokuDB::TypeMap" );

    is( $t->resolve("KiokuDB_Test_CA"), $n, "resolve isa entry for base class" );
    is( $t->resolve("KiokuDB_Test_CA::Sub"), $n, "resolve isa entry for subclass" );
    is( $t->resolve("KiokuDB_Test_Foo"), $n, "alias resolution of isa entry" );
    is( $t->resolve("KiokuDB_Test_Bar"), $n, "alias resolution of isa entry" );
    is( $t->resolve("Blarfla"), undef, "failed resolution of random string" );
    is( $t->resolve("Unknown::KiokuDB_Test_Foo"), $n, "alias to isa entry" );
}

{
    # typemap inheritence

    my $ca = KiokuDB::TypeMap::Entry::Naive->new;
    my $foo = KiokuDB::TypeMap::Entry::Naive->new;

    my $t1 = KiokuDB::TypeMap->new(
        includes => [
            KiokuDB::TypeMap->new(
                entries => {
                    'KiokuDB_Test_CA' => $ca,
                },
            ),
        ],
        entries => {
            'KiokuDB_Test_Foo' => $foo,
        }
    );

    my $t2 = KiokuDB::TypeMap->new(
        entries => {
            'KiokuDB_Test_CA' => $ca,
        },
        includes => [
            KiokuDB::TypeMap->new(
                entries => {
                    'KiokuDB_Test_Foo' => $foo,
                }
            ),
        ],
    );

    my $t3 = KiokuDB::TypeMap->new(
        includes => [
            KiokuDB::TypeMap->new(
                entries => {
                    'KiokuDB_Test_CA' => $ca,
                },
            ),
            KiokuDB::TypeMap->new(
                entries => {
                    'KiokuDB_Test_Foo' => $foo,
                }
            ),
        ],
    );

    my @desc = ( "inherit KiokuDB_Test_CA", "inherit KiokuDB_Test_Foo", "inherit both" );
    foreach my $t ( $t1, $t2, $t3 ) {
        my $desc = "(". shift(@desc) . ")";

        isa_ok( $t, "KiokuDB::TypeMap" );

        is( $t->resolve("KiokuDB_Test_CA"), $ca, "resolve KiokuDB_Test_CA entry $desc" );
        is( $t->resolve("KiokuDB_Test_Foo"), $foo, "resolve KiokuDB_Test_Foo entry $desc" );
        is( $t->resolve("KiokuDB_Test_CA::Sub"), undef, "failed resolution $desc" );
        is( $t->resolve("KiokuDB_Test_Bar"), undef, "failed resolution $desc" );
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
                    'KiokuDB_Test_CA' => $ca,
                },
            ),
        ],
        isa_entries => {
            'KiokuDB_Test_Foo' => $foo,
        }
    );

    my $t2 = KiokuDB::TypeMap->new(
        isa_entries => {
            'KiokuDB_Test_CA' => $ca,
        },
        includes => [
            KiokuDB::TypeMap->new(
                isa_entries => {
                    'KiokuDB_Test_Foo' => $foo,
                }
            ),
        ],
    );

    my $t3 = KiokuDB::TypeMap->new(
        includes => [
            KiokuDB::TypeMap->new(
                isa_entries => {
                    'KiokuDB_Test_CA' => $ca,
                },
            ),
            KiokuDB::TypeMap->new(
                isa_entries => {
                    'KiokuDB_Test_Foo' => $foo,
                }
            ),
        ],
    );

    my @desc = ( "inherit KiokuDB_Test_CA", "inherit KiokuDB_Test_Foo", "inherit both" );
    foreach my $t ( $t1, $t2, $t3 ) {
        my $desc = "(". shift(@desc) . ")";

        isa_ok( $t, "KiokuDB::TypeMap" );

        is_deeply( $t->all_isa_entry_classes, [qw(KiokuDB_Test_Foo KiokuDB_Test_CA)], "isa entry classes" );

        is( $t->resolve("KiokuDB_Test_CA"), $ca, "resolve KiokuDB_Test_CA entry $desc" );
        is( $t->resolve("KiokuDB_Test_Foo"), $foo, "resolve KiokuDB_Test_Foo entry $desc" );
        is( $t->resolve("KiokuDB_Test_CA::Sub"), $ca, "resolve KiokuDB_Test_CA entry for subclass $desc" );
        is( $t->resolve("KiokuDB_Test_Bar"), $foo, "resolve KiokuDB_Test_Foo entry for subclass $desc" );
    }
}

{
    # typemap conflicts

    my $ca = KiokuDB::TypeMap::Entry::Naive->new;

    throws_ok {
        KiokuDB::TypeMap->new(
            entries => {
                'KiokuDB_Test_CA' => $ca,
            },
            isa_entries => {
                'KiokuDB_Test_CA' => $ca,
            }
        );
    } qr/\bKiokuDB_Test_CA\b/, "regular conflicting with isa entry";

}

{
    # typemap inheritence conflicts

    my $ca = KiokuDB::TypeMap::Entry::Naive->new;

    throws_ok {
        KiokuDB::TypeMap->new(
            includes => [
                KiokuDB::TypeMap->new(
                    entries => {
                        'KiokuDB_Test_CA' => $ca,
                    },
                ),
                KiokuDB::TypeMap->new(
                    entries => {
                        'KiokuDB_Test_CA' => $ca,
                    }
                ),
            ],
        );
    } qr/\bKiokuDB_Test_CA\b/, "regular entry conflict";

    throws_ok {
        KiokuDB::TypeMap->new(
            includes => [
                KiokuDB::TypeMap->new(
                    isa_entries => {
                        'KiokuDB_Test_CA' => $ca,
                    },
                ),
                KiokuDB::TypeMap->new(
                    isa_entries => {
                        'KiokuDB_Test_CA' => $ca,
                    }
                ),
            ],
        );
    } qr/\bKiokuDB_Test_CA\b/, "isa entry conflict";

    throws_ok {
        KiokuDB::TypeMap->new(
            includes => [
                KiokuDB::TypeMap->new(
                    isa_entries => {
                        'KiokuDB_Test_CA' => $ca,
                    },
                ),
                KiokuDB::TypeMap->new(
                    entries => {
                        'KiokuDB_Test_CA' => $ca,
                    }
                ),
            ],
        );
    } qr/\bKiokuDB_Test_CA\b/, "mixed entry conflict";
}


done_testing;

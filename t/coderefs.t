#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;

use ok 'KiokuDB';

my $dir = KiokuDB->connect("hash");

{

    package WithCodeRef;
    use KiokuDB::Class;

    has coderef => (
        is       => 'rw',
        isa      => 'CodeRef',
        required => 1,
    );

    sub apply { shift->coderef->(@_) }
}

sub obj (&) { WithCodeRef->new( coderef => $_[0] ) }

{
    my $id;

    {
        my $obj = obj { 4 + $_[0] };

        my $s = $dir->new_scope;

        lives_ok { $id = $dir->store($obj) } "store object with coderef";
    }

    $dir->live_objects->clear; # non closure coderefs live forever

    is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

    {
        my $s = $dir->new_scope;

        $id and my $obj = $dir->lookup($id);

        isa_ok $obj, 'WithCodeRef';
        is eval { $obj->coderef->(38) }, 42, "apply coderef",
    }
}

{
    $dir->live_objects->clear;

    {
        my $s = $dir->new_scope;

        my ( $x, @x, %x );

        # these tests cause leaks in 5.8 if they use Test::Exception

        eval { $dir->store( sv  => sub { $x++ } ) };
        ok( !$@, "SV" );
        eval { $dir->store( av  => sub { $x[0]++ } ) };
        ok( !$@, "AV" );
        eval { $dir->store( hv  => sub { $x{foo}++ } ) };
        ok( !$@, "HV" );
        eval { $dir->store( all => sub { $x++; $x[0]++; $x{foo}++ } ) };
        ok( !$@, "SV, AV, HV" );
    }

    {
        foreach my $id ( qw(sv av hv all) ) {
            is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

            my $s = $dir->new_scope;

            my $sub;
            lives_ok { $sub = $dir->lookup($id) } "load closure $id";

            ok( $sub, "thawed closure" );

            is( eval { $sub->() }, 0, "first invocation" );
            is( eval { $sub->() }, 1, "second invocation" );
        }
    }
}

{
    $dir->live_objects->clear;

    sub generate_counter {
        my $i = shift;

        return obj {
            return ++$i;
        }
    }

    my $id;

    {
        my $obj = generate_counter(0);

        # kick the counter once with first object.
        is( $obj->coderef->(), 1, "apply closure before storing" );

        my $s = $dir->new_scope;
        lives_ok { $id = $dir->store($obj) } "store object with closure";
    }

    is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

    {
        my $s = $dir->new_scope;
        $id and my $obj = $dir->lookup($id);

        is eval { $obj->apply }, 2, "closure variable thawed";
    }

    is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

    {
        my $s = $dir->new_scope;
        $id and my $obj = $dir->lookup($id);

        is eval { $obj->apply }, 2, "closure variable update not stored without call to update";

        ok( $dir->object_to_id($obj->coderef), "code ref has an ID" );

        eval { $dir->deep_update($obj->coderef) };
    }

    is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

    {
        my $s = $dir->new_scope;
        $id and my $obj = $dir->lookup($id);

        is eval { $obj->apply }, 3, "closure variable updated";
    }
}

sub closure_pair {
    my $i = shift;
    return (
        sub {
            return ++$i;
        },
        sub { $i },
    );
}

{
    my @ids;

    {
        my ( $count, $peek ) = map { &obj($_) } closure_pair(0);

        is( $peek->apply, 0, "peek" );
        $count->apply;
        is( $peek->apply, 1, "peek" );

        my $s = $dir->new_scope;
        lives_ok { @ids = $dir->store( $count, $peek ) } "store pair of closures";
    }

    is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

    {
        my $s = $dir->new_scope;

        my ( $count, $peek ) = $dir->lookup(@ids);

        ok( $count, "count thawed" );
        ok( $peek, "peek thawed" );

        is eval { $peek->apply }, 1, "closure sharing";;
        is eval { $count->apply }, 2, "closure sharing";
        is eval { $peek->apply }, 2, "closure sharing thawed";
    }
}

{
    my @ids;

    {
        my ( $count, $peek ) = closure_pair(0);

        is( $peek->(), 0, "peek" );
        $count->();
        is( $peek->(), 1, "peek" );

        my $s = $dir->new_scope;
        lives_ok { @ids = $dir->store( $count, $peek ) } "store pair of closures";
    }

    is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

    {
        my $s = $dir->new_scope;

        my ( $count, $peek ) = $dir->lookup(@ids);

        ok( $count, "count thawed" );
        ok( $peek, "peek thawed" );

        is eval { $peek->() }, 1, "closure sharing";;
        is eval { $count->() }, 2, "closure sharing";
        is eval { $peek->() }, 2, "closure sharing thawed";

        $dir->deep_update($count);
    }

    is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

    {
        my $s = $dir->new_scope;

        my ( $count, $peek ) = $dir->lookup(@ids);

        is eval { $peek->() }, 2, "closure sharing thawed after deep update from other closure";
    }
}

{
    my @ids;

    {
        my ( $count, $peek ) = closure_pair(0);

        is( $peek->(), 0, "peek" );
        $count->();
        is( $peek->(), 1, "peek" );

        my $s = $dir->new_scope;
        lives_ok { $ids[0] = $dir->store($count) } "store count closure";
        lives_ok { $ids[1] = $dir->store($peek ) } "store peek closures";
    }

    is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

    {
        my $s = $dir->new_scope;

        my ( $count, $peek ) = $dir->lookup(@ids);

        ok( $count, "count thawed" );
        ok( $peek, "peek thawed" );

        is eval { $peek->() }, 1, "closure sharing";;
        is eval { $count->() }, 2, "closure sharing";
        is eval { $peek->() }, 2, "closure sharing thawed";

        $dir->deep_update($count);
    }

    is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

    {
        my $s = $dir->new_scope;

        my ( $count, $peek ) = $dir->lookup(@ids);

        is eval { $peek->() }, 2, "closure sharing thawed after deep update from other closure";
    }
}

{
    my @ids;

    {
        my ( $count, $peek ) = closure_pair(0);

        is( $peek->(), 0, "peek" );
        $count->();
        is( $peek->(), 1, "peek" );

        my $s = $dir->new_scope;
        lives_ok { @ids = $dir->store( $count, $peek ) } "store pair of closures";
    }

    is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

    {
        my $s = $dir->new_scope;

        my $peek = $dir->lookup($ids[1]);

        ok( $peek, "peek thawed" );

        is eval { $peek->() }, 1, "closure sharing";;
    }

    {
        my $s = $dir->new_scope;

        my $count = $dir->lookup($ids[0]);

        ok( $count, "count thawed" );

        is eval { $count->() }, 2, "closure sharing";

        $dir->deep_update($count);
    }

    {
        my $s = $dir->new_scope;

        my $peek = $dir->lookup($ids[1]);

        ok( $peek, "peek thawed" );

        is eval { $peek->() }, 2, "closure sharing after disjoint update";
    }
}

{
    my @ids;

    {
        my ( $count, $peek ) = closure_pair(0);

        is( $peek->(), 0, "peek" );
        $count->();
        is( $peek->(), 1, "peek" );

        my $s = $dir->new_scope;
        lives_ok { @ids = $dir->store( $count, $peek ) } "store pair of closures";
    }

    is_deeply( [ $dir->live_objects->live_objects ], [], "no live objects" );

    {
        my $s = $dir->new_scope;

        my $peek = $dir->lookup($ids[1]);

        ok( $peek, "peek thawed" );

        is eval { $peek->() }, 1, "closure sharing";;

        my $count = $dir->lookup($ids[0]);

        ok( $count, "count thawed" );

        is eval { $count->() }, 2, "closure sharing";

        is eval { $peek->() }, 2, "closure sharing after disjoint update (both values live)";
    }
}

{
    my ( $set_id, $get_id );

    {
        my %names;

        ( $set_id, $get_id ) = $dir->txn_do( scope => 1, body => sub {
            $dir->insert( sub { $names{$_[0]} = $_[1] }, sub { $names{$_[0]} } );
        });

        is_deeply( [ $dir->live_objects->live_objects ], [ \%names ], "names is live" );

        {
            my $s = $dir->new_scope;

            my $set = $dir->lookup($set_id);

            ok( $set, "got set" );

            $set->( foo => 42 );

            is_deeply( \%names, { foo => 42 }, "still live closure variable updated" );

            $dir->update(\%names);
        }
    }

    {
        my $s = $dir->new_scope;

        my $get = $dir->lookup($get_id);

        is( $get->("foo"), 42, "names updated" );
    }
}

sub blah { 42 }

{
    my $blah_id= $dir->txn_do( scope => 1, body => sub {
        $dir->insert(\&blah)
    });

    $dir->live_objects->clear;

    {
        my $s = $dir->new_scope;

        my $blah = $dir->lookup($blah_id);

        ok( $blah, "got named sub" );

        is( $blah->(), 42, "correct value" );

        is( $blah, \&blah, "right refaddr" );
    }

    $dir->live_objects->clear;
}

{
    $dir->txn_do( scope => 1, body => sub {
        $dir->backend->insert(
            KiokuDB::Entry->new(
                id => "lalala",
                data => {
                    package => "KiokuDB::Test::Employee",
                    name    => "lalala",
                },
                class => "CODE",
            ),
        );
    });

    {
        my $s = $dir->new_scope;

        ok( !exists($INC{"KiokuDB/Test/Employee.pm"}), "Employee.pm not loaded" );

        my $sub = $dir->lookup("lalala");

        ok( $sub, "loaded sub" );

        ok( $INC{"KiokuDB/Test/Employee.pm"}, "Employee.pm loaded" );

        is( $sub, \&KiokuDB::Test::Employee::lalala, "right refaddr" );
        is( $sub->(), 333, "right value" );
    }

    $dir->live_objects->clear;
}

{
    my $sub_id = $dir->txn_do( scope => 1, body => sub {
        $dir->insert(\&KiokuDB::Test::Employee::company);
    });

    my $entry = $dir->live_objects->id_to_entry($sub_id);

    ok( !exists($entry->{data}{file}), "Moose accessor detected" );
    is_deeply( $entry->{data}, { package => "KiokuDB::Test::Employee", name => "company" }, "FQ reference only" );

    $dir->live_objects->clear;
}


{
    my $sub_id = $dir->txn_do( scope => 1, body => sub {
        $dir->insert(\&Scalar::Util::weaken);
    });

    my $entry = $dir->live_objects->id_to_entry($sub_id);

    ok( !exists($entry->{data}{file}), "XSUB detected" );
    is_deeply( $entry->{data}, { package => "Scalar::Util", name => "weaken" }, "FQ reference only" );

    $dir->live_objects->clear;
}

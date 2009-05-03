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
    local $TODO = "CodeRef storage not supported yet";

    my $id;

    {
        my $obj = obj { 4 + $_[0] };

        my $s = $dir->new_scope;

        lives_ok { $id = $dir->store($obj) };
    }

    {
        my $s = $dir->new_scope;

        $id and my $obj = $dir->lookup($id);

        isa_ok $obj, 'WithCodeRef';
        is eval { $obj->coderef->(38) }, 42,
    }
}

{
    local $TODO = "closure storage not supported yet";

    sub generate_counter {
        my $i = shift;

        return obj {
            return ++$i;
        }
    }

    my $id;

    {
        my $i = 1;
        my $obj = generate_counter(1);

        # kick the counter once with first object.
        is( $obj->coderef->(), 1 );

        my $s = $dir->new_scope;
        lives_ok { $id = $dir->store($obj) };
    }

    {
        my $s = $dir->new_scope;
        $id and my $obj = $dir->lookup($id);

        is eval { $obj->apply }, 2, "closure variable thawed";
    }

    {
        my $s = $dir->new_scope;
        $id and my $obj = $dir->lookup($id);

        is eval { $obj->apply }, 2, "closure variable update not stored without call to update";

        lives_ok { $dir->deep_update($obj) } "deep update lived";
    }

    {
        my $s = $dir->new_scope;
        $id and my $obj = $dir->lookup($id);

        is eval { $obj->apply }, 3, "closure variable updated";
    }
}

{
    local $TODO = "closure storage not supported yet";

    sub closure_pair {
        my $i = shift;
        return (
            sub {
                return ++$i;
            },
            sub { $i },
        );
    }

    my @ids;

    {
        my @objs = generate_counter(0);

        $objs[0]->apply;

        my $s = $dir->new_scope;
        lives_ok { @ids = $dir->store( @objs ) };
    }

    {
        my $s = $dir->new_scope;

        my ( $count, $peek ) = $dir->lookup(@ids);

        is eval { $peek->apply }, 1;
        is eval { $count->apply }, 2;
        is eval { $peek->apply }, 2, "closure sharing thawed";
    }
}

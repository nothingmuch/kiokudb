#!/usr/bin/perl

package KiokuDB::Test::Fixture::ObjectGraph;
use Moose;

use Test::More;
use Scalar::Util qw(weaken);

use KiokuDB::Test::Person;

sub p {
    my @args = @_;
    unshift @args, "name" if @args % 2;
    KiokuDB::Test::Person->new(@args);
}

sub married {
    my ( $a, $b, @kids ) = @_;
    $a->so($b);
    $b->so($a);

    foreach my $parent ( $a, $b ) {
        my @kids_copy = @kids;
        weaken($_) for @kids_copy;
        $parent->kids(\@kids_copy);
    }

    foreach my $child ( @kids ) {
        my @parents = ( $a, $b );
        weaken($_) for @parents;
        $child->parents(\@parents);
    }
}

sub clique {
    my ( @buddies ) = @_;

    foreach my $member ( @buddies ) {
        my @rest = grep { $_ != $member } @buddies;
        $member->friends(\@rest);
        weaken($_) for @rest;
    }
}

use namespace::clean -except => 'meta';

with qw(KiokuDB::Test::Fixture) => { excludes => [qw/populate sort/] };

has [qw(homer dubya putin)] => (
    isa => "Str",
    is  => "rw",
);

sub sort { 100 }

sub create {
    my $self = shift;

    my @r;

    push @r, my $bart     = p("Bart Simpson");
    push @r, my $lisa     = p("Lisa Simpson");
    push @r, my $maggie   = p("Maggie Simpson");
    push @r, my $marge    = p("Marge Simpson");
    push @r, my $homer    = p("Homer Simpson");
    push @r, my $grandpa  = p("Abe Simpson");
    push @r, my $mona     = p("Mona Simpson");
    push @r, my $milhouse = p("Milhouse");
    push @r, my $patty    = p("Patty Bouvier");
    push @r, my $selma    = p("Selma Bouvier");
    push @r, my $jaquelin = p("Jacqueline Bouvier");
    push @r, my $clancy   = p("Clancy Bouvier");

    married($marge, $homer, $bart, $lisa, $maggie);
    married($grandpa, $mona, $homer);
    married($jaquelin, $clancy, $marge, $selma, $patty);
    clique($bart, $milhouse);

    push @r, my $junior    = p("Geroge W. Bush");
    push @r, my $laura     = p("Laura Bush");
    push @r, my $the_drunk = p("Jenna Bush");
    push @r, my $other_one = p("Barbara Pierce Bush");
    push @r, my $daddy     = p("George H. W. Bush");
    push @r, my $barb      = p("Barbara Bush");
    push @r, my $jeb       = p("Jeb Bush");
    push @r, my $dick      = p("Dick Cheney");
    push @r, my $condie    = p("Condoleezza Rice");
    push @r, my $putin     = p("Vladimir Putin");

    married( $junior, $laura, $the_drunk, $other_one );
    married( $daddy, $barb, $junior, $jeb );
    clique( $junior, $condie, $dick );

    push @{ $junior->friends }, $putin;

    return ( \@r, $junior, $putin, $homer );
}

sub populate {
    my $self = shift;

    my $s = $self->new_scope;

    my ( $r, $junior, $putin, $homer, $retain ) = $self->create;

    my @roots = $self->store_ok( $junior, $putin, $homer );

    $self->dubya($roots[0]);
    $self->putin($roots[1]);
    $self->homer($roots[2]);
}

sub verify {
    my $self = shift;

    $self->no_live_objects;

    $self->txn_lives(sub {
        my $junior = $self->lookup_obj_ok( $self->dubya, "KiokuDB::Test::Person" );

        is( $junior->so->name, "Laura Bush", "ref to other object" );
        is( $junior->so->so, $junior, "mututal ref" );

        is_deeply(
            [ map { $_->name } @{ $junior->parents } ],
            [ "George H. W. Bush", "Barbara Bush" ],
            "ref in auxillary structure",
        );

        is_deeply(
            [ grep { $_ == $junior } @{ $junior->parents->[0]->kids } ],
            [ $junior ],
            "mutual ref in auxillary structure"
        );

        is( $junior->parents->[0]->so, $junior->parents->[1], "mutual refs in nested structure" );

        is_deeply(
            $junior->kids->[0]->parents,
            [ $junior, $junior->so ],
            "mutual refs in nested and non nested structure",
        );

        is_deeply(
            [ map { $_->name } @{ $junior->friends } ],
            [ "Condoleezza Rice", "Dick Cheney", "Vladimir Putin" ],
            "mutual refs in nested and non nested structure",
        );

        is_deeply(
            $junior->friends->[-1]->friends,
            [],
            "Putin is paranoid",
        );

        pop @{ $junior->friends };

        $self->update_ok($junior);
    });

    $self->no_live_objects();

    $self->txn_lives(sub {
        my $junior = $self->lookup_obj_ok( $self->dubya, "KiokuDB::Test::Person" );

        is_deeply(
            [ map { $_->name } @{ $junior->friends } ],
            [ "Condoleezza Rice", "Dick Cheney" ],
            "Georgia got plastered",
        );

        $self->live_objects_are(
            $junior,
            $junior->so,
            @{ $junior->friends },
            @{ $junior->kids },
            @{ $junior->parents },
            $junior->parents->[0]->kids->[-1], # jeb
        );

        is(
            scalar(grep { /Putin/ } map { $_->name } $self->live_objects),
            0,
            "Putin is a dead object",
        );

        $junior->job("Warlord");
        $junior->parents->[0]->job("Puppet Master");
        $junior->friends->[0]->job("Secretary of State");
        $junior->so->job("Prima Donna, Author, Teacher, Librarian");

        $self->update_live_objects;
    });

    $self->no_live_objects;

    $self->txn_lives(sub {
        my $homer = $self->lookup_obj_ok( $self->homer, "KiokuDB::Test::Person" );

        {
            my $marge = $homer->so;

            $homer->name("Homer J. Simpson");

            is( $marge->so->name, "Homer J. Simpson", "inter object rels" );
        }

        $homer->job("Safety Inspector, Sector 7-G");

        $self->update_ok($homer);
    });

    $self->no_live_objects;

    $self->txn_lives(sub {
        my $s = $self->new_scope;

        my $homer = $self->lookup_obj_ok( $self->homer, "KiokuDB::Test::Person" );

        is( $homer->name, "Homer J. Simpson", "name" );
    });

    $self->no_live_objects;

    $self->txn_lives(sub {
        my $s = $self->new_scope;

        my $putin = $self->lookup_obj_ok($self->putin);

        $self->live_objects_are( $putin );

        foreach my $job ("President", "Prime Minister", "BDFL", "DFL") {
            $putin->job($job);
            $self->update_ok($putin);
        }
    });

    $self->no_live_objects;

    $self->txn_lives(sub {
        my $putin = $self->lookup_obj_ok($self->putin);

        is( $putin->job, "DFL", "updated in storage" );

        $self->delete_ok($putin);

        $self->deleted_ok($self->putin);

        is( $self->lookup($self->putin), undef, "lookup no longer returns object" );
    });

    $self->no_live_objects;

    $self->deleted_ok( $self->putin );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

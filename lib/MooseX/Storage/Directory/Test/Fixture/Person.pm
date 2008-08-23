#!/usr/bin/perl

package MooseX::Storage::Directory::Test::Fixture::Person;
use Moose;

use Test::More;

use Data::Structure::Util qw(circular_off);

use MooseX::Storage::Directory::Test::Person;

sub p {
    my @args = @_;
    unshift @args, "name" if @args % 2;
    MooseX::Storage::Directory::Test::Person->new(@args);
}

sub married {
    my ( $a, $b, @kids ) = @_;
    $a->so($b);
    $b->so($a);
    $_->kids([ @kids ]) for $a, $b;
    $_->parents([ $a, $b ]) for @kids;
}

sub clique {
    my ( @buddies ) = @_;

    foreach my $member ( @buddies ) {
        $member->friends([ grep { $_ != $member } @buddies ]);
    }
}

use namespace::clean -except => 'meta';

with qw(MooseX::Storage::Directory::Test::Fixture);

has root => ( # as in "of the problem"
    isa => "Str",
    is  => "rw",
);

sub populate {
    my $self = shift;

    my $junior    = p("Geroge W. Bush");
    my $laura     = p("Laura Bush");
    my $the_drunk = p("Jenna Bush");
    my $other_one = p("Barbara Pierce Bush");
    my $daddy     = p("George H. W. Bush");
    my $barb      = p("Barbara Bush");
    my $jeb       = p("Jeb Bush");
    my $dick      = p("Dick Cheney");
    my $condie    = p("Condoleezza Rice");
    my $putin     = p("Vladimir Putin");

    married( $junior, $laura, $the_drunk, $other_one );
    married( $daddy, $barb, $junior, $jeb );
    clique( $junior, $condie, $dick );

    push @{ $junior->friends }, $putin;

    $self->root( $self->directory->store( $junior ) );
    
    circular_off($junior);
}

sub verify {
    my $self = shift;

    is_deeply( [ $self->live_objects->live_objects ], [], "no live objects" );

    my $junior = $self->directory->lookup( $self->root );

    isa_ok( $junior, "MooseX::Storage::Directory::Test::Person" );

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

    $self->directory->update($junior);

    circular_off($junior);
    undef $junior;
    is_deeply( [ $self->live_objects->live_objects ], [], "no live objects" );

    $junior = $self->directory->lookup( $self->root );

    isa_ok( $junior, "MooseX::Storage::Directory::Test::Person" );

    is_deeply(
        [ map { $_->name } @{ $junior->friends } ],
        [ "Condoleezza Rice", "Dick Cheney" ],
        "Georgia got plastered",
    );

}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

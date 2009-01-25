package KiokuDB::Test::Fixture::Concurrency;
use Moose;

use Test::More;
use Test::Exception;

use List::Util qw(sum);
use Scope::Guard;
use POSIX qw(_exit :sys_wait_h);

use namespace::clean -except => 'meta';

with qw(KiokuDB::Test::Fixture);

use constant required_backend_roles => qw(Clear TXN Concurrency::POSIX);

use constant FORKS => 20;
use constant COUNTERS => 250;
use constant ACCOUNTS => 250;
use constant ITER => 10;

my @ids = qw(foo bar gorch baz);

{
    package Foo;
    use Moose;

    has bar => ( is => 'rw' );
}

has exit => (
    isa => "Int",
    is  => "rw",
    default => 0,
);

before precheck => sub {
    my $self = shift;

};

sub create {
    return (
        counter => { value => 0 },
        (map { ( "counter_$_"   => { value => 0 } ) } 1 .. COUNTERS ),
        (map { ( "${_}_account" => { value => 0 } ) } 1 .. ACCOUNTS),
    );
}

sub run {
    my $self = shift;

    SKIP: {
        local $Test::Builder::Level = $Test::Builder::Level + 1;

        $self->precheck;

        lives_ok {
            local $Test::Builder::Level = $Test::Builder::Level - 1;
            $self->txn_do(sub {
                my $s = $self->new_scope;
                $self->backend->clear;
                $self->populate;
            });
        } "populated OK";

        $self->clear_directory;

        $self->verify;

        is_deeply( [ $self->live_objects ], [ ], "no live objects at end of " . $self->name . " fixture" );

        $self->clear_live_objects;
    }
}

sub verify {
    my $self = shift;

    ok( !$self->has_directory, "no directory object" );

    # force re-instantiation of directory
    $self->clear_directory;

    foreach my $num ( 1 .. FORKS ) {
        defined(my $pid = fork) or die $!;
        next if $pid;

        my $guard = Scope::Guard->new(sub {
            # avoid cleanups on errors
            use POSIX qw(_exit);
            _exit($self->exit);
        });

        # make sure each child gets a different random seed
        srand($$ ^ time);

        $self->run_child($num);
    }

    my $skip = 0;

    while ( wait > 0 ) {
        do {
            $skip++ if $?
        } while waitpid(-1, WNOHANG) > 0;

        $self->check_consistency;
    }

    $self->check_counters($skip);
}

sub check_consistency {
    my $self = shift;

    my $ok;

    my ( $counter, @accounts );

    attempt: foreach my $attempt ( 1 .. FORKS ) {
        last attempt if eval {
            $self->txn_do(sub {
                my $s = $self->new_scope;

                $counter = $self->lookup("counter")->{value};

                @accounts = map { $_->{value} } $self->lookup(map { "${_}_account" } 1 .. ACCOUNTS);
            });

            ++$ok;
        };
    }


    SKIP: {
        skip "lock contention", 3 unless $ok;

        cmp_ok( $counter, '>=', 0, "counter not 0" );
        cmp_ok( $counter, '<=', FORKS, "counter <= counters" );

        is( sum(@accounts), 0, "account sum is 0 (state is consistent)" );
    };
}

sub check_counters {
    my ( $self, $skip ) = @_;

    $self->txn_do(sub {
        my $s = $self->new_scope;

        my $counter = $self->lookup_ok("counter");
        is( $counter->{value}, FORKS-$skip, "total counter value" );

        my @counters = $self->lookup_ok(map { "counter_$_" } 1 .. COUNTERS);

        is( sum(map { $_->{value} } @counters), FORKS-$skip, "counters sum" );
    });
}

sub run_child {
    my ( $self, $child ) = @_;

    for ( 1 .. ITER ) {
        eval {
            $self->txn_do(sub {
                my $s = $self->new_scope;

                my $id = @ids[int rand @ids];

                if ( my $foo = $self->lookup($id) ) {
                    if ( rand > 0.5 ) {
                        $foo->bar("foo");
                        $self->update($foo);
                    } else {
                        $self->delete($foo);
                    }
                } else {
                    $self->insert( foo => Foo->new( bar => "bar" ) );
                }

                my ( $one, $two ) = $self->lookup( map { int(rand ACCOUNTS) . "_account" } 1 .. 2 );

                my $amount = int(rand 10000);
                $one->{value} += $amount;
                $two->{value} -= $amount;

                select(undef,undef,undef,0.01) if rand > 0.5;

                $self->update($one, $two);
            });
        };

        select(undef,undef,undef, 0.01);
    }

    my $ok;

    attempt: foreach my $attempt ( 1 .. FORKS*2 ) {
        last attempt if eval {
            $self->txn_do(sub {
                my $s = $self->new_scope;

                my $counter = $self->lookup("counter");

                my $counter_two = $self->lookup("counter_" . int rand COUNTERS);

                select(undef,undef,undef,0.02 * rand) if rand > 0.5;

                $counter_two->{value}++;
                $self->update($counter_two);

                $counter->{value}++;
                $self->update($counter);
            });

            ++$ok;
        };

        select(undef,undef,undef, 0.05);
    }

    $self->exit(1) unless $ok;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

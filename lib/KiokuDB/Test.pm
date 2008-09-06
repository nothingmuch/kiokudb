#!/usr/bin/perl

package KiokuDB::Test;

use strict;
use warnings;

use Scalar::Util qw(blessed);
use Test::More;

use namespace::clean;

use Sub::Exporter -setup => {
    exports => [qw(run_all_fixtures)],
    groups  => { default => [-all] },
};

sub run_all_fixtures {
    my ( $with ) = @_;

    my $get_dir = blessed($with) ? sub { $with } : $with;

    SKIP: {
        skip "fixtures ($@)" => 1, unless eval { require Data::Structure::Util };
        skip "fixtures ($@)" => 1, unless eval { require Module::Pluggable::Object };

        my $mp = Module::Pluggable::Object->new(
            search_path => "KiokuDB::Test::Fixture",
            require     => 1,
        );

        foreach my $fixture ( sort { $a->sort <=> $b->sort } $mp->plugins ) {
            $fixture->new( directory => $fixture->$get_dir )->run;
        }
    }
}

__PACKAGE__

__END__

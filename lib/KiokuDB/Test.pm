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

=head1 NAME

KiokuDB::Test - Reusable tests for L<KiokuDB> backend authors.

=head1 SYNOPSIS

    use Test::More 'no_plan';

    use KiokuDB::Test;

    use ok "KiokuDB::Backend::MySpecialBackend";

    my $b = KiokuDB::Backend::MySpecialBackend->new( ... );

    run_all_fixtures( KiokuDB->new( backend => $b ) );

=head1 DESCRIPTION

This module loads and runs L<KiokuDB::Test::Fixture>s against a L<KiokuDB>
directory instance.

=head1 EXPORTS

=over 4

=item run_all_fixtures $dir

=item run_all_fixtures sub { return $dir }

Runs all the L<KiokuDB::Test::Fixture> objects against your dir.

If you need a new instance of L<KiokuDB> for every fixture, pass in a code
reference.

This will load all the modules in the L<KiokuDB::Test::Fixture> namespace, and
run them against your directory.

Fixtures generally check for backend roles and skip unless the backend supports
that set of features.

=back

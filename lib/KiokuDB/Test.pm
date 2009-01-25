#!/usr/bin/perl

package KiokuDB::Test;

use strict;
use warnings;

use Scalar::Util qw(blessed);
use Test::More;

use Module::Pluggable::Object;

use namespace::clean;

use Sub::Exporter -setup => {
    exports => [qw(run_all_fixtures)],
    groups  => { default => [-all] },
};

my $mp = Module::Pluggable::Object->new(
    search_path => "KiokuDB::Test::Fixture",
    require     => 1,
);

my @fixtures = sort { $a->sort <=> $b->sort } $mp->plugins;

sub run_all_fixtures {
    my ( $with ) = @_;

    my $get_dir = blessed($with) ? sub { $with } : $with;

    for ( 1 .. ( $ENV{KIOKUDB_REPEAT_FIXTURES} || 1 ) ) {
        require List::Util and @fixtures = List::Util::shuffle(@fixtures) if $ENV{KIOKUDB_SHUFFLE_FIXTURES};
        foreach my $fixture ( @fixtures ) {
            next if $ENV{KIOKUDB_FIXTURE} and $fixture->name ne $ENV{KIOKUDB_FIXTURE};
            $fixture->new( get_directory => $get_dir )->run;
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

#!/usr/bin/perl

package KiokuDB::Util;

use strict;
use warnings;

use Path::Class;

use Carp qw(croak);
use Scalar::Util qw(blessed);

use namespace::clean;

use Sub::Exporter -setup => {
    exports => [qw(set weak_set dsn_to_backend)],
};

sub weak_set {
    require KiokuDB::Set::Transient;
    KiokuDB::Set::Transient->new( set => Set::Object::Weak->new(@_) )
}

sub set {
    require KiokuDB::Set::Transient;
    KiokuDB::Set::Transient->new( set => Set::Object->new(@_) );
}

my %monikers = (
    "hash"    => "Hash",
    "bdb"     => "BDB",
    "bdb-gin" => "BDB::GIN",
    "jspon"   => "JSPON",
    "couchdb" => "CouchDB",
);

sub dsn_to_backend {
    my ( $dsn, @args ) = @_;

    if ( my ( $moniker, $rest ) = ( $dsn =~ /^([\w-]+)(?::(.*))?$/ ) ) {
        $moniker = $monikers{$moniker} || $moniker;
        my $class = "KiokuDB::Backend::$moniker";

        Class::MOP::load_class($class);
        return $class->new_from_dsn($rest, @args);
    } else {
        croak "Malformed DSN: $dsn";
    }
}

sub load_config {
    my ( $base ) = @_;

    my $config_file = dir($base)->file("kiokudb.yml");

    $config_file->openr;

    require MooseX::YAML;
    MooseX::YAML::LoadFile($config_file);
}

sub config_to_backend {
    my ( $config, %args ) = @_;

    my $base = delete($args{base});

    my $backend = $config->{backend};

    return $backend if blessed($backend);

    my $backend_class = $backend->{class};
    Class::MOP::load_class($backend_class);

    return $backend_class->new_from_dsn_params(
        ( defined($base) ? ( dir => $base->subdir("data") ) : () ),
        %$backend,
        %args,
    );
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Util - Utility functions for working with KiokuDB

=head1 SYNOPSIS

    use KiokuDB::Util qw(set weak_set);

    my $set = set(@objects); # create a transient set

    my $weak = weak_set(@objects); # to avoid circular refs

=head1 DESCRIPTION

This module provides various helper functions for working with L<KiokuDB>.

=head1 EXPORTS

=over 4

=item set

=item weak_set

Instantiate a L<Set::Object> or L<Set::Object::Weak> from the arguments, and
then creates a L<KiokuDB::Set::Transient> with the result.

=back

=cut



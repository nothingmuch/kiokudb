#!/usr/bin/perl

package KiokuDB::Util;

use strict;
use warnings;

use Path::Class::File;

use Carp qw(croak);

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
    my $dsn = shift;

    if ( my ( $moniker, $rest ) = ( $dsn =~ /^([\w-]+)(?::(.*))?$/ ) ) {

        if ( $moniker eq 'config' ) {
            return process_config_file(file($rest));
        } elsif ( my $class = $monikers{$moniker} ) {
            Class::MOP::load_class("KiokuDB::Backend::$class");
            return "KiokuDB::Backend::$class"->new_from_dsn($rest);
        } else {
            Class::MOP::load_class("KiokuDB::Backend::$moniker");
            return "KiokuDB::Backend::$class"->new_from_dsn($rest);
        }
    } else {
        croak "Malformed DSN: $dsn";
    }
}

sub process_config {
    my ( $self, $config ) = @_;

    my %config = %$config;

    croak "No backend configuration provided"
        unless $config{backend};

    my $class = delete $config{class} || "KiokuDB";

    $class->new(
        %config
    );
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Set::Easy - 

=head1 SYNOPSIS

	use KiokuDB::Set::Easy;

=head1 DESCRIPTION

=cut



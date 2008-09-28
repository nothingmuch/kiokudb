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

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Set::Easy - 

=head1 SYNOPSIS

	use KiokuDB::Set::Easy;

=head1 DESCRIPTION

=cut



#!/usr/bin/perl

package KiokuDB::Set::Easy;

use strict;
use warnings;

use Set::Object;

use KiokuDB::Set::Transient;

use Sub::Exporter -setup => {
    exports => [qw(set weak_set)],
};

sub weak_set { KiokuDB::Set::Transient->new( set => Set::Object::Weak->new(@_) ) }
sub set { KiokuDB::Set::Transient->new( set => Set::Object->new(@_) ) }

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Set::Easy - 

=head1 SYNOPSIS

	use KiokuDB::Set::Easy;

=head1 DESCRIPTION

=cut



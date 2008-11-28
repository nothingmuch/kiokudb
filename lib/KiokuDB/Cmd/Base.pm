#!/usr/bin/perl

package KiokuDB::Cmd::Base;
use Moose;

use namespace::clean -except => 'meta';

extends qw(MooseX::App::Cmd::Command);


# this is to enable programatic usage:

has '+usage' => ( required => 0 );

has '+app'   => ( required => 0 );


__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

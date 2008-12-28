#!/usr/bin/perl

package KiokuDB::Role::UUIDs::SerialIDs;
use Moose::Role;

use namespace::clean -except => 'meta';

my $i = "0001"; # so that the first 10k objects sort lexically
sub generate_uuid { $i++ }

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Role::UUIDs::SerialIDs - Serial ID assignment based on a global
counter.

=head1 SYNOPSIS

    # set before loading:

    BEGIN { $KiokuDB::SERIAL_IDS = 1 }

    use KiokuDB;

=head1 DESCRIPTION

This role provides an alternate, development only ID generation role.

The purpose of this role is to ease testing when the database is created from
scratch on each run. Objects will typically be assigned the same IDs between
runs, making things easier to follow.

Do B<NOT> use this role for storage of actual data, because ID clashes are
almost guaranteed to cause data loss.

=cut

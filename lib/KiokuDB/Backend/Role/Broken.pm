#!/usr/bin/perl

package KiokuDB::Backend::Role::Broken;
use Moose::Role;

use namespace::clean -except => 'meta';

requires "skip_fixtures";

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::Role::Broken - Skip test fixtures

=head1 SYNOPSIS

    with qw(KiokuDB::Backend::Role::Broken);

    # e.g. if your backend can't tell apart update from insert:
    use constant skip_fixtures => qw(
        Overwrite
    );

=head1 DESCRIPTION

If your backend can't pass a test fixture you can ask to skip it using this role.

Simply return the fixture's name from the C<skip_fixtures> sub.

=cut



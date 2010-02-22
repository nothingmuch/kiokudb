package KiokuDB::Role::Upgrade::Data;
use Moose::Role;

use namespace::clean;

requires "kiokudb_upgrade_data";

# ex: set sw=4 et:

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Role::Upgrade::Data - Classes that provide their own upgrade routine.

=head1 SYNOPSIS

    with qw(KiokuDB::Role::Upgrade::Data);

    sub kiokudb_upgrade_data {
        my ( $class, %args ) = @_;

        # convert the data from the old version of the class to the new version
        # as necessary

        $args{entry}->derive(
            class_version => our $VERSION,
            ...
        );
    }

=head1 DESCRIPTION

This class allows you to take control the data conversion process completely
(there is only one handler per class, not one handler per version with this
approach).

See L<KiokuDB::Role::Upgrade::Handlers::Table> for a more DWIM approach, and
L<KiokuDB::TypeMap::Entry::MOP> for more details.

package KiokuDB::Role::Upgrade::Handlers::Table;
use Moose::Role;

use namespace::clean;

with qw(KiokuDB::Role::Upgrade::Handlers);

requires "kiokudb_upgrade_handlers_table";

no warnings 'uninitialized';

sub kiokudb_upgrade_handler {
    my ( $class, $version ) = @_;

    my $table = $class->kiokudb_upgrade_handlers_table;

    return grep { defined } $table->{$version};
}

# ex: set sw=4 et:

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Role::Upgrade::Handlers::Table - A role for classes 

=head1 SYNOPSIS

    with qw(KiokuDB::Role::Upgrade::Handlers::Table);

    use constant kiokudb_upgrade_handlers_table => {

        # like the individual entries in class_version_table

        "0.01" => "0.02",
        "0.02" => sub {
            ...
        },
    };

=head1 DESCRIPTION

This class lets you provide the version handling table as part of the class
definition, instead of as arguments to the L<KiokuDB> handle constructor.

See L<KiokuDB::TypeMap::Entry::MOP> more details and
L<KiokuDB::Role::Upgrade::Data> for a lower level alternative.

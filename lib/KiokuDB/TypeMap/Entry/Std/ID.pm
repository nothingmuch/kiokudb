package KiokuDB::TypeMap::Entry::Std::ID;
use Moose::Role;

use namespace::clean -except => 'meta';

sub compile_id {
    my ( $self, $class, @args ) = @_;

    return "generate_uuid";
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::Entry::Std::ID - Provides a default compile_id method

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

This role provides a default compile_id method.  It is designed to be used
in conjunction with other roles to create a full L<KiokuDB::TypeMap::Entry>
implementation.

=cut

package KiokuDB::Alias;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Role::Immutable);

has target => (
    isa => "Ref",
    is  => "ro",
    required => 1,
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Alias - Symbolic links

=head1 SYNOPSIS

    my $alias = KiokuDB::Alias->new(
        target => $obj,
    );

    $dir->store( foo => $alias );

    $dir->lookup("foo"); # returns $obj

=head1 DESCRIPTION

This object provides symbolic links.

These aliases are only resolved using the C<lookup> method. C<id_to_object>
will return the alias object allowing you to inspect it.


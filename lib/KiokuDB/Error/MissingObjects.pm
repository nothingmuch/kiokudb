package KiokuDB::Error::MissingObjects;
use Moose;

use namespace::clean -except => "meta"; # autoclean kills overloads

extends qw(KiokuDB::Error);

has ids => (
    isa => "ArrayRef[Str]",
    reader => "_ids",
    required => 1,
);

sub ids { @{ shift->_ids } }

sub _build_message {
    my $self = shift;

    local $, = ", ";
    return "Objects missing in database: @{ $self->_ids }";
}

sub missing_ids_are {
    my ( $self, @ids ) = @_;

    my %ids = map { $_ => 1 } $self->ids;

    foreach my $id ( @ids ) {
        return unless delete $ids{$id};
    }

    return ( keys(%ids) == 0 )
}

__PACKAGE__->meta->make_immutable;

# ex: set sw=4 et:

__PACKAGE__

__END__

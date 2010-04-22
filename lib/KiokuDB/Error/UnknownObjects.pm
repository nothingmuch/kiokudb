package KiokuDB::Error::UnknownObjects;
use Moose;

use namespace::clean -except => "meta"; # autoclean kills overloads

use overload '""' => "as_string";

with qw(KiokuDB::Error);

has objects => (
    isa => "ArrayRef[Ref]",
    reader => "_objects",
    required => 1,
);

sub objects { @{ shift->_objects } }

sub as_string {
    my $self = shift;

    local $, = ", ";
    return "Unregistered objects cannot be updated in database: @{ $self->_objects }"; # FIXME Devel::PartialDump?
}

__PACKAGE__->meta->make_immutable;

# ex: set sw=4 et:

__PACKAGE__

__END__

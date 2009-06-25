package KiokuDB::TypeMap::Entry::Ref;
use Moose;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::TypeMap::Entry
    KiokuDB::TypeMap::Entry::Std::Compile
    KiokuDB::TypeMap::Entry::Std::ID
);

sub compile_collapse {
    my ( $self, $reftype ) = @_;

    return "visit_ref_fallback";
}

sub compile_expand {
    my ( $self, $reftype ) = @_;

    return "expand_object";
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

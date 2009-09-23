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

sub compile_refresh {
    my ( $self, $class, @args ) = @_;

    return sub {
        my ( $linker, $object, $entry ) = @_;

        my $new = $linker->expand_object($entry);

        require Data::Swap;
        Data::Swap::swap($new, $object); # FIXME remove!

        return $object;
    };
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

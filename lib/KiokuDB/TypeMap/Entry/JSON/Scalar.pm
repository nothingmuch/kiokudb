package KiokuDB::TypeMap::Entry::JSON::Scalar;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry::Std);

sub compile_collapse_body {
    my ( $self, $class ) = @_;

    return sub {
        my ( $collapser, %args ) = @_;

        my $scalar = $args{object};
        
        my $data = $collapser->visit($$scalar);

        $collapser->make_entry(
            %args,
            class => "SCALAR",
            data  => $data,
        );
    };
}

sub compile_expand {
    my ( $self, $reftype ) = @_;

    sub {
        my ( $linker, $entry ) = @_;

        my $scalar;

        $linker->inflate_data($entry->data, \$scalar);

        return \$scalar;
    }
}

sub compile_refresh {
    my ( $self, $class, @args ) = @_;

    return sub {
        my ( $linker, $scalar, $entry ) = @_;

        $linker->inflate_data($entry->data, $scalar );

        return $scalar;
    };
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

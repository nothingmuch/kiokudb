package KiokuDB::TypeMap::Entry::Std::Expand;
use Moose::Role;

no warnings 'recursion';

use namespace::clean -except => 'meta';

requires qw(
    compile_create
    compile_clear
    compile_expand_data
);

sub compile_expand {
    my ( $self, $class, @args ) = @_;

    my $create = $self->compile_create($class, @args);
    my $expand_data = $self->compile_expand_data($class, @args);

    return sub {
        my ( $linker, $entry, @args ) = @_;

        my $instance = $linker->$create($entry, @args);

        # this is registered *before* any other value expansion, to allow circular refs
        $linker->register_object( $entry => $instance );

        $linker->$expand_data($instance, $entry, @args);

        return $instance;
    };
}

sub compile_refresh {
    my ( $self, $class, @args ) = @_;

    my $clear = $self->compile_clear($class, @args);
    my $expand_data = $self->compile_expand_data($class, @args);

    return sub {
        my ( $linker, $instance, $entry, @args ) = @_;

        $linker->$clear($instance, $entry, @args);

        $linker->$expand_data($instance, $entry, @args);
    };
}

__PACKAGE__

__END__

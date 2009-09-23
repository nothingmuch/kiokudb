package KiokuDB::TypeMap::Entry::Std::Compile;
use Moose::Role;

use KiokuDB::TypeMap::Entry::Compiled;

use namespace::clean -except => 'meta';

requires qw(
    compile_collapse
    compile_expand
    compile_id
    compile_refresh
);

sub compile {
    my ( $self, $class, @args ) = @_;

    $self->new_compiled(
        collapse_method => $self->compile_collapse($class, @args),
        expand_method   => $self->compile_expand($class, @args),
        id_method       => $self->compile_id($class, @args),
        refresh_method  => $self->compile_refresh($class, @args),
        class           => $class,
    );
}

sub new_compiled {
    my ( $self, @args ) = @_;

    KiokuDB::TypeMap::Entry::Compiled->new(
        entry           => $self,
        @args,
    );
}

__PACKAGE__

__END__

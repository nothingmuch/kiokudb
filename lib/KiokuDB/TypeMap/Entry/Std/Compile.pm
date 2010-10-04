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

=pod

=head1 NAME

KiokuDB::TypeMap::Entry::Std::Compile - Provides a compile implementation

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

This role provides an implementation for L<KiokuDB::TypeMap::Entry/compile> by
breaking down its requirements into four separated methods.

=head1 REQUIRED METHODS

=over 4

=item compile_collapse

Must return a code reference or method name.  The calling conventions for this
method are described in L<KiokuDB::TypeMap::Entry::Compiled/collapse_method>.

=item compile_expand

Must return a code reference or method name.  The calling conventions for this
method are described in L<KiokuDB::TypeMap::Entry::Compiled/expand_method>.

=item compile_id

Must return a code reference or method name.  The calling conventions for this
method are described in L<KiokuDB::TypeMap::Entry::Compiled/id_method>.

=item compile_refresh

Must return a code reference or method name.  The calling conventions for this
method are described in L<KiokuDB::TypeMap::Entry::Compiled/refresh_method>.

=back

=head1 SEE ALSO

L<KiokuDB::TypeMap::Entry::Compiled>

=cut

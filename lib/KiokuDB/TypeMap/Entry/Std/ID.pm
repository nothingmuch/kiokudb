package KiokuDB::TypeMap::Entry::Std::ID;
use Moose::Role;

use namespace::clean -except => 'meta';

sub compile_id {
    my ( $self, $class, @args ) = @_;

    return "generate_uuid";
}

__PACKAGE__

__END__

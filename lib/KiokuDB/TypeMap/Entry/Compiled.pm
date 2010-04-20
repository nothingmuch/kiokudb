package KiokuDB::TypeMap::Entry::Compiled;
use Moose;

no warnings 'recursion';

use namespace::clean -except => 'meta';

has [qw(expand_method collapse_method id_method refresh_method)] => (
    isa => "CodeRef|Str",
    is  => "ro",
    required => 1,
);

has class => (
    isa => "Str",
    is  => "ro",
    required => 1,
);

has entry => (
    does => "KiokuDB::TypeMap::Entry",
    is   => "ro",
    required => 1,
);

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

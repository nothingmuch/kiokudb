package KiokuDB::Test::Digested;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Role::ID::Digest MooseX::Clone);

has [qw(foo bar)] => ( is => "ro" );

sub digest_parts {
    my $self = shift;

    return $self->foo, $self->bar;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

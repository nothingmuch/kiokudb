package KiokuDB::LiveObjects::Guard;

use Scalar::Util qw(weaken);

use namespace::clean -except => 'meta';

sub new {
    my ( $class, $hash, $key ) = @_;
    my $self = bless [ $hash, $key ], $class;
    weaken $self->[0];
    return $self;
}

sub DESTROY {
    my $self = shift;
    my ( $hash, $key ) = @$self;
    delete $hash->{$key} if $hash;
}

sub dismiss {
    my $self = shift;
    @$self = ();
}

__PACKAGE__

__END__

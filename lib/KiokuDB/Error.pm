package KiokuDB::Error;
use Moose;

use namespace::clean -except => 'meta';

extends qw(Throwable::Error);

has "message" => ( is => "ro", lazy_build => 1 );

sub _build_message { "$_[0]" }

__PACKAGE__->meta->make_immutable;

# ex: set sw=4 et:

__PACKAGE__

__END__

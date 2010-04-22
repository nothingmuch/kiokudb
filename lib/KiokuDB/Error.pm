package KiokuDB::Error;
use Moose::Role;

use namespace::autoclean;

with qw(Throwable);

requires qw(as_string);

# ex: set sw=4 et:

__PACKAGE__

__END__

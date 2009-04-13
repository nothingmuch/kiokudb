package KiokuDB::Role::ID::Digest;
use Moose::Role;

use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Role::ID::Content
    KiokuDB::Role::WithDigest
);

sub kiokudb_object_id { shift->digest }

#has '+digest' => ( traits => [qw(KiokuDB::ID)] ); # to avoid data redundancy?

__PACKAGE__

__END__

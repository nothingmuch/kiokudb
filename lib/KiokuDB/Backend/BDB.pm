#!/usr/bin/perl

package KiokuDB::Backend::BDB;
use Moose;

use Scalar::Util qw(weaken);
use Storable qw(nfreeze thaw);
use BerkeleyDB::Manager;
use MooseX::Types::Path::Class qw(Dir);

use namespace::clean -except => 'meta';

# TODO use a secondary DB to keep track of the root set
# integrate with the Search::GIN bdb backend for additional secondary indexing

# this will require storing GIN extracted data in the database, too

# also port Search::GIN's Data::Stream::Bulk/BDB cursor code
# this should be generic (work with both c_get and c_pget, and the various
# flags)

with qw(
    KiokuDB::Backend
    KiokuDB::Backend::Serialize::Storable
    KiokuDB::Role::StorageUUIDs
);

has dir => (
    isa => Dir,
    is  => "ro",
    required => 1,
    coerce   => 1,
);

has manager => (
    isa => "BerkeleyDB::Manager",
    is  => "ro",
    lazy_build => 1,
);

sub _build_manager {
    my $self = shift;

    my $dir = $self->dir;

    $dir->mkpath;

    BerkeleyDB::Manager->new( home => $dir );
}

has dbm => (
    is      => 'ro',
    isa     => 'Object',
    lazy_build => 1,
);

sub _build_dbm {
    my $self = shift;

    my $db = $self->manager->open_db("objects.db", class => "BerkeleyDB::Hash");

    weaken $self;

    $db->filter_store_key(sub { $_ = $self->format_uid($_) });
    $db->filter_fetch_key(sub { $_ = $self->parse_uid($_) });

    return $db;
}

sub delete {
    my ( $self, @ids_or_entries ) = @_;

    my @uids = map { ref($_) ? $_->id : $_ } @ids_or_entries;

    my $dbm = $self->dbm;
    $dbm->db_del($_) for @uids;
}

sub insert {
    my ( $self, @entries ) = @_;
    my $dbm = $self->dbm;
    $dbm->db_put( $_->id => $self->serialize($_) ) for @entries;
}

sub get {
    my ( $self, @uids ) = @_;

    my ( $var, @ret );

    my $dbm = $self->dbm;

    foreach my $uid ( @uids ) {
        $dbm->db_get($uid, $var) == 0 || return;
        push @ret, $var;
    }

    return map { $self->deserialize($_) } @ret;
}

sub exists {
    my ( $self, @uids ) = @_;
    my $dbm = $self->dbm;
    my $v;
    map { $dbm->db_get($_, $v) == 0 } @uids;
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Backend::BDB -

=head1 SYNOPSIS

	use KiokuDB::Backend::BDB;

=head1 DESCRIPTION

=cut


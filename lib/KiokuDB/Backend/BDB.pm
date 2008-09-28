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
    KiokuDB::Backend::Clear
    KiokuDB::Backend::TXN
    KiokuDB::Backend::Scan
    KiokuDB::Backend::Query::Simple::Linear
);

has dir => (
    isa => Dir,
    is  => "ro",
    coerce => 1,
);

has manager => (
    isa => "BerkeleyDB::Manager",
    is  => "ro",
    lazy_build => 1,
    #handles => "KiokuDB::Backend::TXN",
);

sub txn_begin { shift->manager->txn_begin(@_) }
sub txn_commit { shift->manager->txn_commit(@_) }
sub txn_rollback { shift->manager->txn_rollback(@_) }
sub txn_do { shift->manager->txn_do(@_) }

sub _build_manager {
    my $self = shift;

    my $dir = $self->dir || die "Either 'manager' or 'dir' is required";;

    $dir->mkpath;

    BerkeleyDB::Manager->new( home => $dir );
}

has primary_db => (
    is      => 'ro',
    isa     => 'Object',
    lazy_build => 1,
);

sub BUILD { shift->primary_db } # early

sub _build_primary_db {
    my $self = shift;

    $self->manager->open_db("objects.db", class => "BerkeleyDB::Hash");
}

sub delete {
    my ( $self, @ids_or_entries ) = @_;

    my @uids = map { ref($_) ? $_->id : $_ } @ids_or_entries;

    my $primary_db = $self->primary_db;
    $primary_db->db_del($_) for @uids;
}

sub insert {
    my ( $self, @entries ) = @_;
    my $primary_db = $self->primary_db;
    $primary_db->db_put( $_->id => $self->serialize($_) ) for @entries;
}

sub get {
    my ( $self, @uids ) = @_;

    my ( $var, @ret );

    my $primary_db = $self->primary_db;

    foreach my $uid ( @uids ) {
        $primary_db->db_get($uid, $var) == 0 || return;
        push @ret, $var;
    }

    return map { $self->deserialize($_) } @ret;
}

sub exists {
    my ( $self, @uids ) = @_;
    my $primary_db = $self->primary_db;
    my $v;
    map { $primary_db->db_get($_, $v) == 0 } @uids;
}

sub clear {
    my $self = shift;

    my $count = 0;

    $self->primary_db->truncate($count);

    return $count;
}

sub all_entries {
    my $self = shift;

    $self->manager->cursor_stream(
        db => $self->primary_db,
        values => 1,
    )->filter(sub {[ map { $self->deserialize($_) } @$_ ]});
}

# sub root_entries { } # secondary index?

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


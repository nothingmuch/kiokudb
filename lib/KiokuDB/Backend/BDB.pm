#!/usr/bin/perl

package KiokuDB::Backend::BDB;
use Moose;

use Scalar::Util qw(weaken);
use Storable qw(nfreeze thaw);
use BerkeleyDB;
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

has environment => (
    is   => 'ro',
    isa  => 'BerkeleyDB::Env',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $db = $self->dir;
        $db->mkpath;
        return BerkeleyDB::Env->new(
            -Home  => $db->stringify,
            # we need all this for transactions
            -Flags => DB_CREATE | DB_INIT_LOCK | DB_INIT_LOG |
                      DB_INIT_TXN | DB_INIT_MPOOL,
        ) || die $BerkeleyDB::Error;
    },
);

has dbm => (
    is      => 'ro',
    isa     => 'Object',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $hash = BerkeleyDB::Btree->new(
            -Env      => $self->environment,
            -Filename => 'objects.db',
            -Flags    => DB_CREATE,
        ) || die $BerkeleyDB::Error;

        weaken $self;

        $hash->filter_store_key(sub { $_ = $self->format_uid($_) });
        $hash->filter_fetch_key(sub { $_ = $self->parse_uid($_) });
        $hash->filter_store_value(sub { $_ = $self->serialize($_) });
        $hash->filter_fetch_value(sub { $_ = $self->deserialize($_) });

        return $hash;
    },
);

sub delete {
    my ( $self, @uids ) = @_;
    my $dbm = $self->dbm;
    $dbm->db_del($_) for @uids;
}

sub insert {
    my ( $self, @entries ) = @_;
    my $dbm = $self->dbm;
    $dbm->db_put( $_->id => $_ ) for @entries;
}

sub get {
    my ( $self, @uids ) = @_;

    my ( $var, @ret );

    my $dbm = $self->dbm;

    foreach my $uid ( @uids ) {
        $dbm->db_get($uid, $var) == 0 || return;
        push @ret, $var;
    }

    return @ret;
}

sub exists {
    my ( $self, @uids ) = @_;
    my $dbm = $self->dbm;
    # fucking wasteful
    map { $dbm->db_get($_, my $var) == 0 } @uids;
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


#!/usr/bin/perl

package MooseX::Storage::Directory::Backend::BDB;
use Moose;

use Storable qw(nfreeze thaw);
use BerkeleyDB;
use MooseX::Types::Path::Class qw(Dir);

use namespace::clean -except => 'meta';

with qw(MooseX::Storage::Directory::Backend);

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
        );
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
        );

        $hash->filter_store_value(sub { $_ = nfreeze($_) });
        $hash->filter_fetch_value(sub { $_ = thaw($_) });

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
    my ( $self, $uid ) = @_;
    $self->dbm->db_get($uid, my $var) == 0 || return;
    return $var;
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

MooseX::Storage::Directory::Backend::BDB - 

=head1 SYNOPSIS

	use MooseX::Storage::Directory::Backend::BDB;

=head1 DESCRIPTION

=cut



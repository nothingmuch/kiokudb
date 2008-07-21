#!/usr/bin/perl

package MooseX::Storage::Directory::Backend::JSPON;
use Moose;

use Carp qw(croak);

use File::NFSLock;
use IO::AtomicFile;
use JSON;

use MooseX::Storage::Directory::Backend::JSPON::Expander;
use MooseX::Storage::Directory::Backend::JSPON::Collapser;

use MooseX::Types::Path::Class qw(Dir File);

use namespace::clean -except => 'meta';

with qw(MooseX::Storage::Directory::Backend);

sub BUILD {
    my $self = shift;

    $self->object_dir->mkpath;
    $self->root_set_dir->mkpath;
}

has dir => (
    isa => Dir,
    is  => "ro",
    required => 1,
    coerce   => 1,
);

has object_dir => (
    isa => Dir,
    is  => "ro",
    lazy_build => 1,
);

sub _build_object_dir {
    my $self = shift;
    $self->dir->subdir("all");
}

has root_set_dir => (
    isa => Dir,
    is  => "ro",
    lazy_build => 1,
);

sub _build_root_set_dir {
    my $self = shift;
    $self->dir->subdir("root");
}

has lock_file => (
    isa => File,
    is  => "ro",
    lazy_build => 1,
);

sub _build_lock_file {
    my $self = shift;
    $self->dir->file("lock");
}

has json => (
    isa => "Object",
    is  => "rw",
    builder => "_build_json",
    handles => [qw(encode decode)],
);

sub _build_json {
    JSON->new->utf8->pretty;
}

has expander => (
    isa => "MooseX::Storage::Directory::Backend::JSPON::Expander",
    is  => "rw",
    builder => "_build_expander",
    handles => { expand_jspon => "visit" },
);

sub _build_expander {
    MooseX::Storage::Directory::Backend::JSPON::Expander->new;
}

has collapser => (
    isa => "MooseX::Storage::Directory::Backend::JSPON::Collapser",
    is  => "rw",
    builder => "_build_collapser",
    handles => { collapse_jspon => "visit" },
);

sub _build_collapser {
    MooseX::Storage::Directory::Backend::JSPON::Collapser->new;
}

sub write_lock {
    my $self = shift;

    File::NFSLock->new({ file => $self->lock_file->stringify, lock_type => "EXCLUSIVE" });
}

sub get {
    my ( $self, @uids ) = @_;

    if ( @uids == 1 ) {
        return $self->get_entry($uids[0]);
    } else {
        return map { $self->get_entry($_) } @uids;
    }
}

sub insert {
    my ( $self, @entries ) = @_;

    foreach my $entry ( @entries ) {
        $self->insert_entry($entry);
    }
}

sub delete {
    my ( $self, @uids ) = @_;

    foreach my $uid ( @uids ) {
        foreach my $file ( $self->object_file($uid), $self->root_set_file($uid) ) {
            $file->remove;
        }
    }
}

sub exists {
    my ( $self, @uids ) = @_;

    map { -e $self->object_file($_) } @uids;
}

sub get_entry {
    my ( $self, $uid ) = @_;

    my $json = $self->object_file($uid)->slurp;

    my $data = $self->decode($json);

    my $entry = $self->expand_jspon($data);

    $entry->root(1) if -e $self->root_set_file($uid);

    return $entry;
}

sub insert_entry {
    my ( $self, $entry ) = @_;

    my $file = $self->object_file($entry->id);

    my $data = $self->collapse_jspon($entry);

    my $fh = IO::AtomicFile->open( $file, "w" );

    $fh->print( $self->encode($data) );

    {
        my $lock = $self->write_lock;

        $fh->close || croak "Couldn't store: $!";

        my $root_file = $self->root_set_file($entry->id);
        $root_file->remove;
        link( $file, $root_file ) if $entry->root;
    }
}

sub uid_basename {
    my ( $self, $uid ) = @_;
    return "${uid}.json";   
}

sub object_file {
    my ( $self, $uid ) = @_;
    my $base = $self->uid_basename($uid);
    $self->object_dir->file($base);
}

sub root_set_file {
    my ( $self, $uid ) = @_;
    my $base = $self->uid_basename($uid);
    $self->root_set_dir->file($base);
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

MooseX::Storage::Directory::Backend::JSPON - JSON file backend with JSPON
reference semantics

=cut

#!/usr/bin/perl

package KiokuDB::Set;
use Moose has => { -as => "attr" }; # Set::Object needs a 'has' method

use namespace::clean -except => "meta";

# typemap maps directly to references
# interactions with sets whose dir != cause full loading
# interactions with set::object cause available loading, only refs are considered in the Set::Object
# interactions with sets of the same dir require no loading at all

attr dir => (
    isa => "KiokuDB",
    is  => "ro",
);

attr set => (
    isa => "Set::Object",
    is  => "ro",
    default => sub { Set::Object::Weak->new },
    handles => [qw(size)],
);

attr loaded => (
    isa => "Bool",
    is  => "rw",
);

sub clear {
    my $self = shift;

    $self->loaded(1);
    $self->set->clear();
}


sub includes {
    my ( $self, @members ) = @_;

    $self->_load_available;

    $self->_fix_args(\@members);
    $self->set->includes(@members);
}

sub has { (shift)->includes(@_) }
sub contains { (shift)->includes(@_) }
sub element { (shift)->member(@_) }
sub member {
    my $self = shift;
    my $item = shift;
    return ( $self->includes($item) ?
        $item : undef );
}

sub remove {
    my ( $self, @members ) = @_;

    $self->_load_available;

    $self->_fix_args(\@members);
    $self->set->remove(@members);
}

sub insert {
    my ( $self, @members ) = @_;

    $self->_load_available;

    $self->loaded($self->_fix_args(\@members) && $self->loaded);
    $self->set->insert(@members);
}

sub members {
    my $self = shift;

    $self->_load_all();
    return $self->set->members;
}

sub _load_all {
    my $self = shift;

    return if $self->loaded;

    my $set = $self->set;

    my @members = $set->members;

    if ( my @ids = grep { not ref } @members ) {
        my @objs = $self->dir->lookup(@ids);
        $set->remove(@ids);
        $set->insert(@objs);
    }

    $self->loaded(1);
}

sub _load_available {
    my $self = shift;

    my @members = $self->set->members;

    if ( my @ids = grep { not ref } @members ) {
        my %objs;
        @objs{@ids} = $self->dir->live_objects->ids_to_objects(@ids);

        my $bad;

        my $set = $self->set;

        foreach my $id ( @ids ) {
            if ( defined( my $obj = $objs{$id} ) ) {
                $set->remove($id);
                $set->insert($obj);
            } else {
                $bad++;
            }
        }

        $self->loaded(1) unless $bad;
    } else {
        $self->loaded(1);
    }
}

sub _fix_args {
    my ( $self, $members ) = @_;

    my $live = $self->dir->live_objects;

    my $bad;

    foreach my $member ( @$members ) {
        unless ( ref $member ) {
            if ( my $obj = $live->id_to_object($member) ) {
                $member = $obj;
            } else {
                $bad++;
            }
        }
    }

    return !$bad;
}

# intersection invert equal not equal union difference superset subset proper_superset proper_subset unique symmetric_difference

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Set - 

=head1 SYNOPSIS

	use KiokuDB::Set;

    my $set = KiokuDB::Set->new( ;

    $set->insert($id);

    $set->insert( 

=head1 DESCRIPTION

=cut



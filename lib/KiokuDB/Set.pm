#!/usr/bin/perl

package KiokuDB::Set;
use Moose::Role qw(requires); # need a 'has' method

use namespace::clean -except => "meta";

requires qw(
    clear
    includes
    members
    insert
    remove
    size
);

sub has { (shift)->includes(@_) }
sub contains { (shift)->includes(@_) }
sub element { (shift)->member(@_) }
sub member {
    my $self = shift;
    my $item = shift;
    return ( $self->includes($item) ?
        $item : undef );
}

sub _apply {
    my ( $self, $method, @sets ) = @_;

    my @real_sets;

    foreach my $set ( @sets ) {
        if ( my $meth = $set->can("_load_all") ) {
            $set->$meth;
        }
        
        if ( my $inner = $set->can("_objects") ) {
            push @real_sets, $set->$inner;
        } elsif ( $set->isa("Set::Object") ) {
            push @real_sets, $set;
        } else {
            die "Bad set interaction: $self with $set";
        }
    }

    $self->meta->clone_instance( $self, set => $self->_objects->$method( @real_sets ) );
}

# FIXME what else
sub union { shift->_apply( union => @_ ) }
sub intersection { shift->_apply( union => @_ ) }
sub subset { shift->_apply( union => @_ ) }
sub difference { shift->_apply( union => @_ ) }
sub equal { shift->_apply( union => @_ ) }

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



#!/usr/bin/perl

package MooseX::Storage::Directory::Backend::JSPON::Expander;
use Moose;

use Carp qw(croak);

use MooseX::Storage::Directory::Entry;
use MooseX::Storage::Directory::Reference;

use namespace::clean -except => 'meta';

extends qw(Data::Visitor);

sub visit_hash_key {
    my ( $self, $key ) = @_;
    $key =~ s/^public:://x;
    return $key;
}

# Note: this method is destructive
# maybe it's a good idea to copy $hash before deleting items out of it?
override visit_hash => sub {
    my ( $self, $hash ) = @_;

    if ( exists $hash->{id} ) {
        # check the class more thoroughly here ...
        my ($class, $version, $authority) = (split '-' => delete $hash->{__CLASS__});
        my $meta = eval { $class->meta };
        croak "Class ($class) is not loaded, cannot unpack" if $@; 

        ( my $id = delete $hash->{id} ) =~ s/\.json$//;;

        return MooseX::Storage::Directory::Entry->new(
            id    => $id,
            class => $meta,
            data  => super(),
        );
    } elsif ( my $id = $hash->{'$ref'} ) {
        $id =~ s/\.json$//;
        return MooseX::Storage::Directory::Reference->new( id => $id, ( $hash->{is_weak} ? ( is_weak => 1 ) : () ) );
    } else {
        return super();
    }
};

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

MooseX::Storage::Directory::Backend::JSPON::Expander - Inflate JSPON to entry
data.

=cut



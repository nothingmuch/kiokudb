#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::Callback;
use Moose;

no warnings 'recursion';

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry::Std);

has [qw(collapse expand)] => (
    is  => "ro",
    isa => "Str|CodeRef",
    required => 1,
);

has id => (
    is  => "ro",
    isa => "Str|CodeRef",
);

sub compile_collapse_body {
    my ( $self, $class, @args ) = @_;

    my $collapse_object = $self->collapse;

    return sub {
        my ( $self, %args ) = @_;

        my @data = $args{object}->$collapse_object;

        my $data;

        if ( @data == 1 and not ref $data[0] ) {
            $data = $data[0];
        } else {
            $data = [ map { $self->visit($_) } @data ];
        }

        return $self->make_entry(
            %args,
            data => $data,
        );
    };
}

sub compile_expand {
    my ( $self, $class, @args ) =@_;

    my $expand_object = $self->expand;

    return sub {
        my ( $self, $entry ) = @_;

        my @args;

        my $data = $entry->data;

        if ( ref $data ) {
            my $refs = 0;

            foreach my $value ( @$data ) {
                if ( ref $value ) {
                    push @args, undef;
                    $self->inflate_data($value, \$args[-1]);
                    $refs++;
                } else {
                    push @args, $value;
                }
            }

            $self->load_queue if $refs; # force @args to be fully vivified
        } else {
            @args = ( $data );
        }

        # does *NOT* support circular refs
        my $object = $entry->class->$expand_object(@args);

        $self->register_object( $entry => $object );

        return $object;
    };
}

sub compile_id {
    my ( $self, $class, @args ) = @_;

    if ( my $get_id = $self->id ) {
        return sub {
            my ( $self, $object ) = @_;
            $object->$get_id;
        };
    } else {
        return "generate_uuid";
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::Entry::Callback - Callback based inflation/deflation of objects

=head1 SYNOPSIS

    KiokuDB::TypeMap->new(
        entries => {
            'My::Class' => KiokuDB::TypeMap::Entry::Callback->new(
                expand => "new", # My::Class->new(%$self)
                collapse => sub {
                    my $self = shift;
                    return %$self; # provide args to 'new' in this example
                },
                id => sub { "foo" }, # 'id' callback is optional
            ),
        },
    );

=head1 DESCRIPTION

This L<KiokuDB::TypeMap> entry provides callback based inflation/deflation.

The major limitation of this method is that it cannot be used for self
referential structures. This is because the object being inflated is only
constructed after all of its arguments are.

For the overwhelming majority of the use cases this is good enough though.

=head1 ATTRIBUTES

=over 4

=item collapse

A method name or code reference invoked on the object during collapsing.

This is evaluated in list context, and the list of values it returns will be
collapsed by the L<KiokuDB::Collapser> and then store.

=item expand

A method name or code reference invoked on the class of the object during loading.

The arguments are as returned by the C<collapse> callback.

=item id

An optional method name or code reference invoked to get an ID for the object.

If one is not provided the default (UUID based) generation is used.

=item intrinsic

A boolean denoting whether or not the object should be collapsed with no ID,
and serialized as part of its parent object.

This is useful for value like objects, for whom the reference address makes no
difference (such as L<URI> objects).

=back

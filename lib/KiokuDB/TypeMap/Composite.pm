#!/usr/bin/perl

package KiokuDB::TypeMap::Composite;
use Moose::Role;

use KiokuDB::TypeMap;

use namespace::clean -except => 'meta';

{
    package KiokuDB::TypeMap::Composite::TypeMapAttr;
    use Moose::Role;

    use namespace::clean -except => 'meta';

    sub Moose::Meta::Attribute::Custom::Trait::KiokuDB::TypeMap::register_implementation { __PACKAGE__ }
}

has override => (
    isa     => "HashRef[HashRef]",
    is      => "ro",
    default => sub { +{} },
);

has exclude => (
    isa     => "ArrayRef[Str]",
    is      => "ro",
    default => sub { [] },
);

has _exclude => (
    is         => "ro",
    lazy_build => 1,
);

sub _build__exclude {
    my $self = shift;
    return { map { $_ => undef } @{ $self->exclude } };
}

sub _build_includes {
    my $self = shift;

    my @attrs = $self->meta->get_all_attributes;

    my $exclude = $self->_exclude;

    my @typemap_attrs = grep {
        ( my $short_name = $_->name ) =~ s/_typemap$//;

        $_->does("KiokuDB::TypeMap::Composite::TypeMapAttr")
            and
        ( !$short_name or !exists($exclude->{$short_name}) )
            and
        !exists($exclude->{$_->name})
    } @attrs;

    return [ map { $_->get_value($self) } @typemap_attrs ];
}

sub _construct_entry {
    my ( $self, @args ) = @_;

    my $args = $self->_entry_options(@args);

    my $type = delete $args->{type};
    Class::MOP::load_class($type);

    $type->new($args);
}

sub _entry_options {
    my ( $self, %args ) = @_;

    my $class = delete $args{class};

    return { %args, %{ $self->override->{$class} || {} }, };
}

sub _create_entry {
    my ( $self, $class, $entry ) = @_;

    return if exists $self->_exclude->{$class};

    return ( $class => $entry ) if blessed $entry;

    return ( $class => $self->_construct_entry( %$entry, class => $class ) );
}

sub _create_entries {
    my ( $self, $entries ) = @_;

    my $excl;

    return {
        map {
            my $class = $_;
            my $entry = $entries->{$class};

            $self->_create_entry($class, $entry);
        } keys %$entries
    };
}

sub _create_typemap {
    my ( $self, %args ) = @_;

    foreach my $entries ( @args{grep { exists $args{$_} } qw(entries isa_entries does_entries)} ) {
        next unless $entries;
        $entries = $self->_create_entries($entries);
    }

    KiokuDB::TypeMap->new(%args);
}

sub _naive_isa_typemap {
    my ( $self, $class, @args ) = @_;

    $self->_create_typemap(
        isa_entries => {
            $class => {
                type => "KiokuDB::TypeMap::Entry::Naive",
                @args,
            },
        },
    );
}

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::Composite - A role for L<KiokuDB::TypeMaps> created out of
many smaller typemaps

=head1 SYNOPSIS

    package MyTypeMap;
    use Moose;

    extends qw(KiokuDB::TypeMap);

	with qw(KiokuDB::TypeMap::Composite);


    # declare typemaps to inherit from using the KiokuDB::TypeMap trait
    # the 'includes' attribute will be built by collecting these attrs:

    has foo_typemap => (
        traits => [qw(KiokuDB::TypeMap)], # register for inclusion
        does   => "KiokUDB::Role::TypeMap",
        is     => "ro",
        lazy_build => 1,
    );


    # this role also provides convenience methods for creating typemap objects
    # easily:
    sub _build_foo_typemap {
        my $self = shift;

        $self->_create_typemap(
            isa_entries => {
                $class => {
                    type      => 'KiokuDB::TypeMap::Entry::Callback',
                    intrinsic => 1,
                    collapse  => "collapse",
                    expand    => "new",
                },
            },
        );
    }

    sub _build_bar_typemap {
        my $self = shift;

        # create a typemap with one naive isa entry
        $self->_naive_isa_typemap("Class::Foo", @entry_args);
    }





    # you also get some construction time customization:

    MyTypeMap->new(
        exclude => [qw(Class::Blort foo)],
        override => {
            "Class::Blah", => $alternate_entry,
        },
    );

=head1 DESCRIPTION

This role provides a declarative, customizable way to set values for
L<KiokuDB::TypeMap>'s C<includes> attribute.

Any class consuming this role can declare attributes with the trait
C<KiokuDB::TypeMap>.

The result is a typemap instance that inherits from the specified typemap in a
way that is composable for the author and flexible for the user.

L<KiokuDB::TypeMap::Default> is created using this role.

=head1 ATTRIBUTES

=over 4

=item exclude

An array reference containing typemap attribute names (e.g. C<path_class> in
the default typemap) or class name to exclude.

Class exclusions are handled by C<_create_typemap> and do not apply to already
constructed typemaps.

=item override

A hash reference of classes to L<KiokuDB::TypeMap::Entry> objects.

Class overrides are handled by C<_create_typemap> and do not apply to already
constructed typemaps.

Classes which don't have a definition will not be merged into the resulting
typemap, simply create a typemap of your own and inherit if that's what you
want.

=back

=head1 METHODS

=over 4

=item _create_typemap %args

Creates a new typemap.

The entry arguments are converted before passing to L<KiokuDB::TypeMap/new>:

    $self->_create_typemap(
        entries => {
            Foo => {
                type => "KiokuDB::TypeMap::Entry::Naive",
                intrinsic => 1,
            },
        },
    );

The nested hashref will be used as arguments to
L<KiokuDB::TypeMap::Entry::Naive/new> in this example.

C<exclude> and C<override> are taken into account by the hashref conversion
code.

=item _naive_isa_typemap $class, %entry_args

A convenience method to create a one entry typemap with a single inherited
entry for C<$class> of the type L<KiokuDB::TypeMap::Entry::Naive>.

This is useful for when you have a base class that you'd like KiokuDB to
persist automatically:

    sub _build_my_class_typemap {
        shift->_naive_isa_typemap( "My::Class::Base" );
    }

=back

=cut


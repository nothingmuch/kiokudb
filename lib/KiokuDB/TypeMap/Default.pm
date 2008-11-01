#!/usr/bin/perl

package KiokuDB::TypeMap::Default;
use Moose::Role;

use namespace::clean -except => 'meta';

{
    package KiokuDB::TypeMap::Default::TypeMapAttr;
    use Moose::Role;

    use namespace::clean -except => 'meta';

    sub Moose::Meta::Attribute::Custom::Trait::KiokuDB::TypeMap::Default::register_implementation { __PACKAGE__ }
}

has intrinsic_sets => (
    isa     => "Bool",
    is      => "ro",
    default => 0,
);

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

has [qw(
    core_typemap
    tie_typemap
    path_class_typemap
    uri_typemap
    datetime_typemap
    authen_passphrase_typemap
)] => (
    traits     => [qw(KiokuDB::TypeMap::Default)],
    does       => "KiokuDB::Role::TypeMap",
    is         => "ro",
    lazy_build => 1,
);

sub _build__exclude {
    my $self = shift;
    return { map { $_ => undef } @{ $self->exclude } };
}

sub _build_includes {
    my $self = shift;

    my @attrs = $self->meta->compute_all_applicable_attributes;

    my $exclude = $self->_exclude;

    my @typemap_attrs = grep {
        ( my $short_name = $_->name ) =~ s/_typemap$//;

        $_->does("KiokuDB::TypeMap::Default::TypeMapAttr")
            and
        !exists($exclude->{$short_name})
            and
        !exists($exclude->{$_->name})
    } @attrs;

    return [ map { $_->get_value($self) } @typemap_attrs ];
}

sub _create_entry {
    my ( $self, %args ) = @_;

    my $class = $args{class};

    return if exists $self->_exclude->{$class};

    return $class => $self->_construct_entry(%args);
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

sub _create_entries {
    my ( $self, $entries ) = @_;

    return {
        map {
            my $entry = $entries->{$_};

            blessed($entry)
                ? $entry
                : $self->_create_entry(
                      class => $_,
                      %$entry,
                  );
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

requires qw(
    _build_path_class_typemap
    _build_uri_typemap
    _build_datetime_typemap
    _build_authen_passphrase_typemap
);

sub _build_core_typemap {
    my $self = shift;

    $self->_create_typemap(
        isa_entries => {
            'KiokuDB::Set::Base' => {
                type      => "KiokuDB::TypeMap::Entry::Set",
                intrinsic => $self->intrinsic_sets,
            },
        },
    );
}

sub _build_tie_typemap {
    my $self = shift;

    $self->_create_typemap(
        isa_entries => {
            'Tie::RefHash' => {
                type      => 'KiokuDB::TypeMap::Entry::Callback',
                intrinsic => 1,
                collapse  => "STORABLE_freeze",
                expand    => sub {
                    my ( $class, @args ) = @_;
                    my $self = ( bless [], $class );
                    $self->STORABLE_thaw( 0, @args );
                    return $self;
                },
            },
        },
        entries => {
            'Tie::IxHash' => {
                type      => 'KiokuDB::TypeMap::Entry::Naive',
                intrinsic => 1,
            },
        },
    );
}

__PACKAGE__

__END__

=head1 NAME

KiokuDB::TypeMap::Default - A standard L<KiokuDB::TypeMap> with predefined
entries.

=head1 SYNOPSIS

    # the user typemap implicitly inherits from the default one, which is
    # provided by the backend.

    my $dir = KiokuDB->new(
        backend => $b,
        typemap => $user_typemap,
    );

=head1 DESCRIPTION

The default typemap is actually defined per backend, in
L<KiokuDB::TypeMap::Default::JSON> and L<KiokuDB::TypeMap::Default::Storable>.
The list of classes handled by both is the same, but the typemap entries
themselves are tailored to the specific backends' requirements/capabilities.

The entries have no impact unless you are actually using the listed modules.

=head1 SUPPORTED TYPES

=over 4

=item L<KiokuDB::Set>

=item L<Tie::RefHash>

=item L<Tie::IxHash>

=item L<DateTime>

=item L<URI>, L<URI::WithBase>

=item L<Path::Class::Entity>

=item L<Authen::Passphrase>

=back

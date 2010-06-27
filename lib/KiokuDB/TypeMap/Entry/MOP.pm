#!/usr/bin/perl

package KiokuDB::TypeMap::Entry::MOP;
use Moose;

use Scalar::Util qw(refaddr);
use Carp qw(croak);

use KiokuDB::Thunk;

no warnings 'recursion';

sub does_role {
    my ($meta, $role) = @_;
    return unless my $does = $meta->can('does_role');
    return $meta->$does($role);
}

use namespace::clean -except => 'meta';

with (
    'KiokuDB::TypeMap::Entry::Std',
    'KiokuDB::TypeMap::Entry::Std::Expand' => {
        alias => { compile_expand => 'compile_expand_body' },
    }
);

has check_class_versions => (
    isa => "Bool",
    is  => "ro",
    default => 1,
);

has version_table => (
    isa => "HashRef[Str|CodeRef|HashRef]",
    is  => "ro",
    default => sub { return {} },
);

has class_version_table  => (
    isa => "HashRef[HashRef[Str|CodeRef|HashRef]]",
    is  => "ro",
    default => sub { return {} },
);

has write_upgrades => (
    isa => "Bool",
    is  => "ro",
    default => 0,
);

# FIXME collapser and expaner should both be methods in Class::MOP::Class,
# apart from the visit call

sub compile_collapse_body {
    my ( $self, $class, @args ) = @_;

    my $meta = Class::MOP::get_metaclass_by_name($class);

    my @attrs = grep {
        !does_role($_->meta, 'KiokuDB::Meta::Attribute::DoNotSerialize')
            and
        !does_role($_->meta, 'MooseX::Storage::Meta::Attribute::Trait::DoNotSerialize')
    } $meta->get_all_attributes;

    my %lazy;
    foreach my $attr ( @attrs ) {
        $lazy{$attr->name}  = does_role($attr->meta, "KiokuDB::Meta::Attribute::Lazy");
    }

    my $meta_instance = $meta->get_meta_instance;

    my %attrs;

    if ( $meta->is_anon_class ) {

        # FIXME ancestral roles all the way up to first non anon ancestor,
        # at least check for additional attributes or other metadata which we
        # should probably error on anything we can't store

        # theoretically this can do multiple inheritence too

        my $ancestor = $meta;
        my @anon;

        search: {
            push @anon, $ancestor;

            my @super = $ancestor->superclasses;

            if ( @super == 1 ) {
                $ancestor = Class::MOP::get_metaclass_by_name($super[0]);
                if ( $ancestor->is_anon_class ) {
                    redo search;
                }
            } elsif ( @super > 1 ) {
                croak "Cannot resolve anonymous class with multiple inheritence: " . $meta->name;
            } else {
                croak "no super, ancestor: $ancestor (" . $ancestor->name . ")";
            }
        }

        my $class_meta = $ancestor->name;

        foreach my $anon ( reverse @anon ) {
            $class_meta = {
                roles => [
                    map { $_->name } map {
                        $_->isa("Moose::Meta::Role::Composite")
                            ? @{$_->get_roles}
                            : $_
                    } @{ $anon->roles }
                ],
                superclasses => [ $class_meta ],
            };
        }

        if ( $class_meta->{superclasses}[0] eq $ancestor->name ) {
            # no need for redundancy, expansion will provide this as the default
            delete $class_meta->{superclasses};
        }

        %attrs = (
            class => $ancestor->name,
            class_meta => $class_meta,
        );
    }

    my $immutable  = does_role($meta, "KiokuDB::Role::Immutable");
    my $content_id = does_role($meta, "KiokuDB::Role::ID::Content");

    my @extra_args;

    if ( defined( my $version = $meta->version ) ) {
        push @extra_args, class_version => "$version"; # force stringification for version objects
    }

    return (
        sub {
            my ( $self, %args ) = @_;

            my $object = $args{object};

            if ( $immutable ) {
                # FIXME this doesn't handle unset_root
                if ( $self->live_objects->object_in_storage($object) ) {
                    return $self->make_skip_entry( %args, prev => $self->live_objects->object_to_entry($object) );
                } elsif ( $content_id ) {
                    if ( ($self->backend->exists($args{id}))[0] ) { # exists works in list context
                        return $self->make_skip_entry(%args);
                    }
                }
            }

            my %collapsed;

            attr: foreach my $attr ( @attrs ) {
                my $name = $attr->name;
                if ( $attr->has_value($object) ) {
                    if ( $lazy{$name} ) {
                        my $value = $meta_instance->Class::MOP::Instance::get_slot_value($object, $name); # FIXME fix KiokuDB::Meta::Instance to allow fetching thunk

                        if ( ref $value eq 'KiokuDB::Thunk' ) {
                            $collapsed{$name} = $value->collapsed;
                            next attr;
                        }
                    }

                    my $value = $attr->get_raw_value($object);
                    $collapsed{$name} = ref($value) ? $self->visit($value) : $value;
                }
            }

            return $self->make_entry(
                @extra_args,
                %args,
                data => \%collapsed,
            );
        },
        %attrs,
    );
}

sub compile_expand {
    my ( $self, $class, $resolver, @args ) = @_;

    my $meta = Class::MOP::get_metaclass_by_name($class);

    my $typemap_entry = $self;

    my $anon = $meta->is_anon_class;

    my $inner = $self->compile_expand_body($class, $resolver, @args);

    my $version = $meta->version;

    return sub {
        my ( $linker, $entry, @args ) = @_;

        if ( $entry->has_class_meta and !$anon ) {
            # the entry is for an anonymous subclass of this class, we need to
            # compile that entry and short circuit to it. if $anon is true then
            # we're already compiled, and the class_meta is already handled
            my $anon_meta = $self->reconstruct_anon_class($entry);

            my $anon_class = $anon_meta->name;

            unless ( $resolver->resolved($anon_class) ) {
                $resolver->compile_entry($anon_class, $typemap_entry);
            }

            my $method = $resolver->expand_method($anon_class);
            return $linker->$method($entry, @args);
        }

        if ( !$self->check_class_versions or $self->is_version_up_to_date($meta, $version, $entry->class_version) ) {
            $linker->$inner($entry, @args);
        } else {
            my $upgraded = $self->upgrade_entry( linker => $linker, meta => $meta, entry => $entry, expand_args => \@args);

            if ( $self->write_upgrades ) {
                croak "Upgraded entry can't be updated (mismatch in 'prev' chain)"
                    unless refaddr($entry) == refaddr($upgraded->root_prev);

                $linker->backend->insert($upgraded);
            }

            $linker->$inner($upgraded, @args);
        }
    }
}

{ my %cache;
sub is_version_up_to_date {
    my ( $self, $meta, $version, $entry_version ) = @_;

    # no clever stuff, only if they are the same string they are the same version

    no warnings 'uninitialized'; # undef $VERSION is allowed
    return 1 if $version eq $entry_version;

    my $key = join(":", $meta->name, $entry_version); # $VERSION isn't supposed to change at runtime

    return $cache{$key} if exists $cache{$key};

    # check the version table for equivalent versions (recursively)
    # ref handlers are upgrade hooks
    foreach my $handler ( $self->find_version_handlers($meta, $entry_version) ) {
        return $cache{$key} = $self->is_version_up_to_date( $meta, $version, $handler ) if not ref $handler;
    }

    return $cache{$key} = undef;
}

sub clear_version_cache { %cache = () }
}

sub find_version_handlers {
    my ( $self, $meta, $version ) = @_;

    no warnings 'uninitialized'; # undef $VERSION is allowed

    if ( does_role($meta, "KiokuDB::Role::Upgrade::Handlers") ) {
        return $meta->name->kiokudb_upgrade_handler($version);
    } else {
        return grep { defined } map { $_->{$version} } $self->class_version_table->{$meta->name}, $self->version_table;
    }
}

sub upgrade_entry {
    my ( $self, %args ) = @_;

    my ( $meta, $entry ) = @args{qw(meta entry)};

    if ( does_role($meta, "KiokuDB::Role::Upgrade::Data") ) {
        return $meta->name->kiokudb_upgrade_data(%args);
    } else {
        return $self->upgrade_entry_from_version( %args, from_version => $entry->class_version );
    }
}

sub upgrade_entry_from_version {
    my ( $self, %args ) = @_;

    my ( $meta, $from_version, $entry ) = @args{qw(meta from_version entry)};

    no warnings 'uninitialized'; # undef $VERSION is allowed

    foreach my $handler ( $self->find_version_handlers($meta, $from_version) ) {
        if ( ref $handler ) {

            my $cb = $self->_process_upgrade_handler($handler);

            # apply handler
            my $converted = $self->$cb(%args);

            if ( $self->is_version_up_to_date( $meta, $meta->version, $converted->class_version ) ) {
                return $converted;
            } elsif ( $entry->class_version eq $converted->class_version ) {
                croak "Upgrade from " . $entry->class_version . " did change 'class_version' field";
            } else {
                # more error context
                return try {
                    $self->upgrade_entry_from_version(%args, entry => $converted, from_version => $converted->class_version);
                } catch {
                    croak "$_\n... when upgrading from $from_version";
                };
            }
        } else {
            # nonref is equivalent version, recursively search for handlers for that version
            return $self->upgrade_entry_from_version( %args, from_version => $handler );
        }
    }

    croak "No handler found for " . $meta->name . " version $from_version" . ( $entry->class_version ne $from_version ? "(entry version is " . $entry->class_version . ")" : "" );
}

sub _process_upgrade_handler {
    my ( $self, $handler ) = @_;

    if ( ref $handler eq 'HASH' ) {
        croak "Data provided in upgrade handler must be a hash"
            if ref $handler->{data} and ref $handler->{data} ne 'HASH';

        croak "No class_version provided in upgrade handler"
            unless defined $handler->{class_version};

        return sub {
            my ( $self, %args ) = @_;

            my $entry = $args{entry};

            croak "Entry data not a hash reference"
                unless ref $entry->data eq 'HASH';

            $entry->derive(
                %$handler,
                data => {
                    %{ $entry->data },
                    %{ $handler->{data} || {} },
                },
            );
        };
    }

    return $handler;
}

sub compile_create {
    my ( $self, $class ) = @_;

    my $meta = Class::MOP::get_metaclass_by_name($class);

    my $meta_instance = $meta->get_meta_instance;

    my $cache = does_role($meta, "KiokuDB::Role::Cacheable");

    my @register_args = (
        ( $cache ? ( cache => 1 ) : () ),
    );

    return sub {
        return ( $meta_instance->create_instance(), @register_args );
    };
}

sub compile_clear {
    my ( $self, $class ) = @_;

    return sub {
        my ( $linker, $obj ) = @_;
        %$obj = (); # FIXME
    }
}

sub compile_expand_data {
    my ( $self, $class, @args ) = @_;

    my $meta = Class::MOP::get_metaclass_by_name($class);

    my $meta_instance = $meta->get_meta_instance;

    my ( %attrs, %lazy );

    my @attrs = grep {
        !does_role($_->meta, 'KiokuDB::Meta::Attribute::DoNotSerialize')
            and
        !does_role($_->meta, 'MooseX::Storage::Meta::Attribute::Trait::DoNotSerialize')
    } $meta->get_all_attributes;

    foreach my $attr ( @attrs ) {
        $attrs{$attr->name} = $attr;
        $lazy{$attr->name}  = does_role($attr->meta, "KiokuDB::Meta::Attribute::Lazy");
    }

    return sub {
        my ( $linker, $instance, $entry, @args ) = @_;

        my $data = $entry->data;

        my @values;

        foreach my $name ( keys %$data ) {
            my $attr = $attrs{$name} or croak "Unknown attribute: $name";
            my $value = $data->{$name};

            if ( ref $value ) {
                if ( $lazy{$name} ) {
                    my $thunk = KiokuDB::Thunk->new( collapsed => $value, linker => $linker, attr => $attr );
                    $attr->set_raw_value($instance, $thunk);
                } else {
                    my @pair = ( $attr, undef );

                    $linker->inflate_data($value, \$pair[1]) if ref $value;
                    push @values, \@pair;
                }
            } else {
                $attr->set_raw_value($instance, $value);
            }
        }

        $linker->queue_finalizer(sub {
            foreach my $pair ( @values ) {
                my ( $attr, $value ) = @$pair;
                $attr->set_raw_value($instance, $value);
                $attr->_weaken_value($instance) if $attr->is_weak_ref;
            }
        });

        return $instance;
    }
}

sub reconstruct_anon_class {
    my ( $self, $entry ) = @_;

    $self->inflate_class_meta(
        superclasses => [ $entry->class ],
        %{ $entry->class_meta },
    );
}

sub inflate_class_meta {
    my ( $self, %meta ) = @_;

    foreach my $super ( @{ $meta{superclasses} } ) {
        $super = $self->inflate_class_meta(%$super)->name if ref $super;
    }

    # FIXME should probably get_meta_by_name($entry->class)
    Moose::Meta::Class->create_anon_class(
        cache => 1,
        %meta,
    );
}

sub compile_id {
    my ( $self, $class ) = @_;

    if ( does_role(Class::MOP::get_metaclass_by_name($class), "KiokuDB::Role::ID") ) {
        return sub {
            my ( $self, $object ) = @_;
            return $object->kiokudb_object_id;
        }
    } else {
        return "generate_uuid";
    }
}

sub should_compile_intrinsic {
    my ( $self, $class, @args ) = @_;

    my $meta = Class::MOP::get_metaclass_by_name($class);

    if ( $self->has_intrinsic ) {
        return $self->intrinsic;
    } elsif ( does_role($meta, "KiokuDB::Role::Intrinsic") ) {
        return 1;
    } else {
        return 0;
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::TypeMap::Entry::MOP - A L<KiokuDB::TypeMap> entry for objects with a
metaclass.

=head1 SYNOPSIS

    KiokuDB::TypeMap->new(
        entries => {
            'My::Class' => KiokuDB::TypeMap::Entry::MOP->new(
                intrinsic => 1,
            ),
        },
    );

=head1 DESCRIPTION

This typemap entry handles collapsing and expanding of L<Moose> based objects.

It supports anonymous classes with runtime roles, the L<KiokuDB::Role::ID> role.

Code for immutable classes is cached and performs several orders of magnitude
better, so make use of L<Moose::Meta::Class/make_immutable>.

=head1 ATTRIBUTES

=over 4

=item intrinsic

If true the object will be collapsed as part of its parent, without an ID.

=item check_class_versions

If true (the default) then class versions will be checked on load and if there
is a mismatch between the stored version number and the current version number,
the version upgrade handler tables will be used to convert the out of date
entry.

=item version_table

=item class_version_table

Tables of handlers.

See also L<KiokuDB::Role::Upgrade::Data> and
L<KiokuDB::Role::Upgrade::Handlers::Table> for convenience roles that do not
require a central table.

The first is a global version table (useful when the typemap entry is only
handling one class) and the second is a table of tables keyed by the class name.

The tables are keyed by version number (as a string, C<undef> and C<""> are
considered the same), and the value can be either a code reference that
processes the entry to bring it up to date, a hash reference of overridden
fields, or a string denoting a version number that this version is equivalent
to.

Version numbers have no actual ordinal meaning, they are taken as simple string
identifiers.

If we had 3 versions, C<1.0>, C<1.1> and C<2.0>, where C<1.1> is a minor update
to the class that requires no structural changes from C<1.0>, our table could
be written like this:

    {
        '1.0' => '1.1', # upgrading the data from 1.0 to 1.1 is a noop
        '1.1' => sub {
            my ( $self, %args ) = @_;

            # manually convert the entry data
            return $entry->clone(
                class_version => '2.0',
                prev => $entry,
                data => ...,
            ),
        },
    }

When an object that was stored as version C<1.0> is retrieved from the
database, and the current definition of the class has C<$VERSION> C<2.0>,
table declares C<1.0> is the same as C<1.1>, so we search for the handler for
C<1.1> and apply it.

The resulting class has the version C<2.0> which is the same as what we have
now, so this object can be thawed.

The callback is invoked with the following arguments:

=over 4

=item entry

The entry to upgrade.

=item from_version

The key under which the handler was found (not necessarily the same as
C<< $entry->class_version >>).

=item meta

The L<Class::MOP::Class> of the entry's class.

=item linker

The L<KiokuDB::Linker> instance that is inflating this object.

Can be used to retrieve additional required objects (cycles are not a problem
but be aware that the objects might not be usable yet at the time of the
callback's invocation).

=back

When a hash is provided as a handler it'll be used to create an entry like
this:

    $entry->derive(
        %$handler,
        data => {
            %{ $entry->data },
            %{ $handler->{data} || {} },
        },
    );

The field C<class_version> is required, and C<data> must contain a hash:

    KiokuDB->connect(
        class_version_table => {
            Foo => {
                "0.02" => {
                    class_version => "0.03", # upgrade 0.02 to 0.03
                    data => {
                        a_new_field => "default_value",
                    },
                },
            },
        },
    );

=item write_upgrades

If true, after applying version upgrade handlers, the updated entry will be
written back to the database.

Defaults to false but might default to true in future versions (unless the
database is in readonly mode).

=back

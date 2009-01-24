package KiokuDB::Collapser::Buffer;
use Moose;

use Hash::Util::FieldHash::Compat qw(idhash);
use Set::Object;

use namespace::clean -except => 'meta';

has live_objects => (
    isa => "KiokuDB::LiveObjects",
    is  => "ro",
    required => 1,
);

has _objects => (
    isa => "HashRef",
    is  => "ro",
    default => sub { idhash my %hash },
);

sub object_to_id {
    my ( $self, $object ) = @_;
    $self->_objects->{$object};
}

sub merged_objects_to_ids {
    my ( $self, @objects ) = @_;

    my $l = $self->live_objects;

    map { $self->object_to_id($_) || $l->object_to_id($_) } @objects;
}

has _ids => (
    isa => "HashRef",
    is  => "ro",
    default => sub { return {} },
);

sub id_to_object {
    my ( $self, $id ) = @_;

    if ( defined ( my $obj = $self->_ids->{$id} ) ) {
        return $obj;
    } else {
        return $self->live_objects->id_to_object($id);
    }
}

has entries => (
    isa => "HashRef",
    is  => "ro",
    default  => sub { return {} },
);

sub id_to_entry {
    my ( $self, $id ) = @_;
    $self->entries->{$id};
}

has intrinsic => (
    isa => "HashRef",
    is  => "ro",
    default => sub { idhash my %hash },
);

sub intrinsic_entry {
    my ( $self, $obj ) = @_;
    $self->intrinsic->{$obj};
}

sub insert_intrinsic {
    my ( $self, $object, $entry ) = @_;
    $self->intrinsic->{$object} = $entry;
}

# a list of the IDs of all simple entries
has simple_entries => (
    isa => 'ArrayRef',
    is  => "ro",
    default => sub { [] },
);

# first_class keeps track of the simple references which are first class
# (either weak or shared, and must have an entry)
has first_class => (
    isa => 'Set::Object',
    is  => "ro",
    default => sub { Set::Object->new },
);

has options => (
    isa => 'HashRef',
    is  => "ro",
    default => sub { {} },
);

sub insert {
    my ( $self, $id, $object ) = @_;

    $self->_objects->{$object} = $id;
    $self->_ids->{$id} = $object;
}

sub insert_entry {
    my ( $self, $id, $entry ) = @_;

    $self->entries->{$id} = $entry;
}

sub compact_entries {
    my $self = shift;

    my ( $entries, $fc, $simple, $options ) = ( $self->entries, $self->first_class, $self->simple_entries, $self->options );

    # unify non shared simple references
    if ( my @flatten = grep { not $fc->includes($_) } @$simple ) {
        my %flatten;
        @flatten{@flatten} = delete @{$entries}{@flatten};

        $self->compact_entry($_, \%flatten) for values %$entries;
    }
}

sub compact_entry {
    my ( $self, $entry, $flatten ) = @_;

    my $data = $entry->data;

    if ( $self->compact_data($data, $flatten) ) {
        $entry->_data($data);
    }
}

sub compact_data {
    my ( $self, $data, $flatten ) = @_;

    if ( ref $data eq 'KiokuDB::Reference' ) {
        my $id = $data->id;

        if ( my $entry = $flatten->{$id} ) {
            # replace reference with data from entry, so that the
            # simple data is inlined, and mark that entry for removal
            $self->compact_entry($entry, $flatten);

            if ( $entry->tied or $entry->class ) {
                $entry->clear_id;
                $_[1] = $entry;
            } else {
                $_[1] = $entry->data;
            }
            return 1;
        }
    } elsif ( ref($data) eq 'ARRAY' ) {
        ref && $self->compact_data($_, $flatten) for @$data;
    } elsif ( ref($data) eq 'HASH' ) {
        ref && $self->compact_data($_, $flatten) for values %$data;
    } elsif ( ref($data) eq 'KiokuDB::Entry' ) {
        $self->compact_entry($data, $flatten);
    } else {
        # passthrough
    }

    return;
}

sub imply_root {
    my ( $self, @ids ) = @_;

    my $entries = $self->entries;

    foreach my $id ( @ids ) {
        my $entry = $entries->{$id} or next;
        next if $entry->has_root; # set by typemap
        $entry->root(1);
    }
}

sub insert_to_backend {
    my ( $self, $backend ) = @_;

    my @insert = values %{ $self->entries };

    $backend->insert(@insert);

    $self->update_entries;
}

sub update_entries {
    my $self = shift;

    my $l = $self->live_objects;
   
    $l->update_entries( values %{ $self->entries } );
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

package KiokuDB::TypeMap::Entry::Closure;
use Moose;

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry::Std);

sub compile_collapse_body {
    my $self = shift;

    require B::Deparse;
    require PadWalker;

    return sub {
        my ( $collapser, %args ) = @_;

        my $sub = $args{object};

        my $pad = PadWalker::closed_over($sub);

        my %data;

        if ( keys %$pad ) {
            my $collapsed_pad = $collapser->visit($pad);

            $data{pad} = $collapsed_pad;

            my $buffer = $collapser->_buffer;
            my $pad_entry_data = blessed $collapsed_pad ? $buffer->id_to_entry( $collapsed_pad->id )->data : $collapsed_pad;

            $buffer->first_class->insert(map { $_->id } values %$pad_entry_data ); # maybe only if entry($_->id)->object's refcount is > 1 (only shared closure vars) ?
        }

        $data{body} = $self->_deparse($sub);

        return $collapser->make_entry(
            %args,
            object => $sub,
            data   => \%data,
        );
    };
}

sub _deparse {
    my ( $self, $cv ) = @_;

    B::Deparse->new->coderef2text($cv);
}

sub compile_expand {
    my $self = shift;

    require PadWalker;

    return sub {
        my ( $linker, $entry ) = @_;

        my ( $body, $pad ) = @{ $entry->data }{qw(body pad)};

        my $inflated_pad;
        $linker->inflate_data( $pad, \$inflated_pad );

        my $sub = $self->_eval_body( $body, $inflated_pad );

        $linker->register_object( $entry => $sub );

        return $sub;
    };
}

sub _eval_body {
    my ( $self, $body, $pad ) = @_;

    my ( $sub, $e ) = do {
        local $@;

        if ( my @vars = keys %$pad ) {
            my $vars = join ", ", @vars;

            my $sub = eval "
                my ( $vars );
                sub $body;
            ";

            my $e = $@;

            PadWalker::set_closed_over($sub, $pad) if $sub;

            ( $sub, $e );
        } else {
            eval "sub $body", $@;
        }
    };

    die $e unless $sub;

    return $sub;
}


__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

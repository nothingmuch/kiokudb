package KiokuDB::TypeMap::Entry::Closure;
use Moose;

use Carp qw(croak);
use Scalar::Util qw(refaddr);

use namespace::clean -except => 'meta';

with qw(KiokuDB::TypeMap::Entry::Std);

sub compile_collapse_body {
    my $self = shift;

    require B;
    require B::Deparse;
    require PadWalker;

    return sub {
        my ( $collapser, %args ) = @_;

        my $sub = $args{object};

        my ( $pkg, $name ) = Class::MOP::get_code_info($sub);

        my %data;

        # FIXME make this customizable on a per sub and per typemap level
        if ( $name eq '__ANON__' ) {
            my $pad = PadWalker::closed_over($sub);

            if ( keys %$pad ) {
                my $collapsed_pad = $collapser->visit($pad);

                $data{pad} = $collapsed_pad;

                my $buffer = $collapser->_buffer;
                my $pad_entry_data = blessed $collapsed_pad ? $buffer->id_to_entry( $collapsed_pad->id )->data : $collapsed_pad;

                $buffer->first_class->insert(map { $_->id } values %$pad_entry_data ); # maybe only if entry($_->id)->object's refcount is > 1 (only shared closure vars) ?
            }

            # FIXME find all GVs in the optree and insert refs to them?
            # i suppose they should be handled like named...
            $data{body} = $self->_deparse($sub);
        } else {
            ( my $pkg_file = "${pkg}.pm" ) =~ s{::}{/}g;

            my $file;

            if ( my $meta = Class::MOP::get_metaclass_by_name($pkg) ) {
                if ( my $method = $meta->get_method($name) ) { 
                    if ( refaddr($method->body) == refaddr($sub)
                            and
                        $method->isa("Class::MOP::Method::Generated")
                            and
                        $method->can("definition_context")
                    ) {
                        $file = $method->definition_context->{file};
                    }
                }
            }

            unless ( defined $file ) {
                my $cv = B::svref_2object($sub);
                $file = $cv->FILE unless $cv->XSUB; # Can't really tell who called newXS or even bootstrap, so we assume the package .pm did
            }

            my $inc_key;

            if ( defined $file ) {
                my %rev_inc = reverse %INC;
                $inc_key = $rev_inc{$file};
                $inc_key = $file unless defined $inc_key;
            }

            if ( defined($inc_key) and $pkg_file ne $inc_key ) {
                $data{file} = $inc_key;
            }

            @data{qw(package name)} = ( $pkg, $name );
        }

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

        my $data = $entry->data;

        if ( exists $data->{body} ) {
            my ( $body, $pad ) = @{ $data }{qw(body pad)};

            my $inflated_pad;
            $linker->inflate_data( $pad, \$inflated_pad );

            my $sub = $self->_eval_body( $linker, $body, $inflated_pad );

            $linker->register_object( $entry => $sub );

            return $sub;
        } else {
            my $fq = join("::", @{ $data }{qw(package name)});
            my $glob = do { no strict 'refs'; *$fq };

            unless ( defined(*{$glob}{CODE}) ) {
                if ( defined(my $file = $data->{file}) ) {
                    require $file unless exists $INC{$file};
                } else {
                    Class::MOP::load_class($data->{package});
                }

                unless ( defined(*{$glob}{CODE}) ) {
                    croak "The subroutine &$data->{name} is no longer defined, but is referred to in the database";
                }
            }

            my $sub = *{$glob}{CODE};

            $linker->register_object( $entry => $sub );

            return $sub;
        }
    };
}

sub compile_refresh {
    my $self = shift;

    return sub {
        croak "refreshing of closures is not yet supported";
    };
}

sub _eval_body {
    my ( $self, $linker, $body, $pad ) = @_;

    my ( $sub, $e ) = do {
        local $@;

        if ( my @vars = keys %$pad ) {
            my $vars = join ", ", @vars;

            # FIXME Parse::Perl
            my $sub = eval "
                my ( $vars );
                sub $body;
            ";

            my $e = $@;

            $linker->queue_finalizer(sub {
                PadWalker::set_closed_over($sub, $pad);
            }) if $sub;

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

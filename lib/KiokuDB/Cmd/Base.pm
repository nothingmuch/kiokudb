#!/usr/bin/perl

package KiokuDB::Cmd::Base;
use Moose;

{
    package Moose::Meta::Attribute::Custom::Trait::EarlyBuild;
    use Moose::Role;
}

BEGIN { local $@; eval "use Time::HiRes qw(time)" };

use namespace::clean -except => 'meta';

extends qw(MooseX::App::Cmd::Command);

with qw(KiokuDB::Cmd::Verbosity);

# this is to enable programatic usage:

has '+usage' => ( required => 0 );

has '+app'   => ( required => 0 );

has exit_code => (
    traits => [qw(NoGetopt)],
    isa => "Int",
    is  => "rw",
    predicate => "has_exit_code",
);

sub _build_attrs {
    my $self = shift;

    foreach my $attr ( grep { $_->does("EarlyBuild") } $self->meta->compute_all_applicable_attributes ) {
        $attr->get_value($self);
    }
}

sub run {
    my $self = shift;

    $self->_build_attrs;

    my $t = -time();
    my $tc = -times;

    inner();
    
    $t += time();
    $tc += times;

    $self->v(sprintf "completed in %.2fs (%.2fs cpu)\n", $t, $tc);

    if ( $self->has_exit_code ) {
        exit $self->exit_code;
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

#!/usr/bin/perl

package KiokuDB::Meta::Instance;
use Moose::Role;

use namespace::clean -except => 'meta';

around 'get_slot_value' => sub {
    my ( $next, $self, $instance, $slot, @args ) = @_;

    my $value = $self->$next($instance, $slot, @args);

    if ( ref($value) eq 'KiokuDB::Thunk' ) {
        $value = $value->vivify($instance);
    }

    return $value;
};

around 'inline_get_slot_value' => sub {
    my ( $next, $self, $instance_expr, $slot_expr, @args ) = @_;

    my $get_expr = $self->$next($instance_expr, $slot_expr, @args);

    return 'do {
        my $value = ' . $get_expr . ';
        if ( ref($value) eq "KiokuDB::Thunk" ) {
            $value = $value->vivify(' . $instance_expr . ');
        }
        $value;
    }'
};

sub inline_get_is_lvalue { 0 }

__PACKAGE__

__END__

=pod

=head1 NAME

KiokuDB::Meta::Instance - L<Moose::Meta::Instnace> level support for lazy loading.

=head1 SYNOPSIS

    # use KiokuDB::Meta::Attribute::Lazy

=head1 DESCRIPTION

This role is applied to the meta instance class automatically by
L<KiokuDB::Class>. When it finds L<KiokuDB::Thunk> objects in the low level
attribute storage it will cause them to be loaded.

This allows your L<Moose::Meta::Attributes> to remain oblivious to the fact
that the value is deferred, making sure that all the type constraints, lazy
defaults, and various other L<Moose> features continue to work normally.


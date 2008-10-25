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

__PACKAGE__

__END__

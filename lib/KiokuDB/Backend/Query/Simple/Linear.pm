#!/usr/bin/perl

package KiokuDB::Backend::Query::Simple::Linear;
use Moose::Role;

use namespace::clean -except => 'meta';

with qw(KiokuDB::Backend::Query::Simple);

requires "root_entries";

sub simple_search {
    my ( $self, $proto ) = @_;

    # FIXME $proto is sql::abstract 2? or...?

    my $root_set = $self->root_entries;

    return $root_set->filter(sub {
        return [ grep {
            my $entry = $_;
            $self->compare_naive($entry->data, $proto);
        } @$_ ]
    });
}

__PACKAGE__

__END__

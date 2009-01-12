#!/usr/bin/perl

package KiokuDB::GC::Naive::Sweep;
use Moose;

use namespace::clean -except => 'meta';

with 'KiokuDB::Role::Scan' => { result_class => "KiokuDB::GC::Naive::Sweep::Results" };

{
    package KiokuDB::GC::Naive::Sweep::Results;
    use Moose;

    use Set::Object;

    has [qw(garbage)] => (
        isa => "Set::Object",
        is  => "ro",
        default => sub { Set::Object->new },
    );

    __PACKAGE__->meta->make_immutable;
}

has mark_results => (
    isa => "KiokuDB::GC::Naive::Mark::Results",
    is  => "ro",
    required => 1,
    handles => qr/.*/,
);

sub process_block {
    my ( $self, %args ) = @_;

    my ( $block, $res ) = @args{qw(block results)};

    my $seen = $self->seen;

    my @ids = map { $_->id } @$block;

    my @garbage = grep { not $seen->includes($_) } @ids;

    $res->garbage->insert(@garbage);
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

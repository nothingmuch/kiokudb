package MooseX::Storage::Directory::WithUUID;
use Moose::Role;
use Moose::Util::TypeConstraints;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Data::UUID;

subtype 'UUID::Str'
    => 'Str'
    => where {
        # ex: 4162F712-1DD2-11B2-B17E-C09EFE1DC403        
        /^[A-Z0-9]+\-[A-Z0-9]+\-[A-Z0-9]+\-[A-Z0-9]+\-[A-Z0-9]+$/
    };

has 'uuid' => (
    is      => 'ro',
    isa     => 'UUID::Str',   
    lazy    => 1,
    default => sub { 
        Data::UUID->new->create_str;
    },
);

no Moose::Role; 1;

__END__

=pod

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS 

=over 4

=item B<>

=back

=head1 BUGS

All complex software has bugs lurking in it, and this module is no 
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 AUTHOR

Stevan Little E<lt>stevan.little@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

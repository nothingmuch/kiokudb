#!/usr/bin/perl

package MooseX::Storage::Directory::Role::UUIDs;
use Moose::Role;

use MooseX::Storage::Directory ();

use namespace::clean -except => 'meta';

BEGIN {
    if ( MooseX::Storage::Directory::SERIAL_IDS() ) {
        my $i = "0001"; # so that the first 10k objects sort lexically
        eval '
            sub generate_uuid  { $i++ }
            sub uuid_to_string { $_[0} }
            sub string_to_uuid { $_[0} }
        ';
    } else {
        my $bin = MooseX::Storage::Directory::RUNTIME_BINARY_UUIDS();

        local $@;
        my @eval;

        if ( eval { require Data::UUID::LibUUID } ) {
            # first try loading Data::UUID::LibUUID, it's faster and cleaner, and makes better UUIDs (not time based)
            push @eval, 'sub generate_uuid { Data::UUID::LibUUID::new_uuid_' . ($bin ? "binary" : "string") . '() }';
            push @eval, q{
                sub uuid_to_string { Data::UUID::LibUUID::uuid_to_string($_[1]) }
                sub string_to_uuid { Data::UUID::LibUUID::uuid_to_binary($_[1])    }
            } if $bin;
        } else {
            # fallback to Data::UUID if Data::UUID::LibUUID is not available
            require Data::UUID;
            push( @eval,
                'my $uuid_gen = Data::UUID->new;',
                'sub generate_uuid { $uuid_gen->create_' . ( $bin ? "bin" : "str" ) . ' }',
            );

            push @eval, q{
                sub uuid_to_string { $uuid_gen->to_string($_[1])   }
                sub string_to_uuid { $uuid_gen->from_string($_[1]) }
            } if $bin;
        }

        # common code for both under no $bin
        unless ( $bin ) {
            push @eval, q{
                sub uuid_to_string { $_[1] }
                sub string_to_uuid { $_[1] }
            };
        }

        eval join("\n", @eval, ' ; 1' ) or die $@;
    }
}


__PACKAGE__

__END__

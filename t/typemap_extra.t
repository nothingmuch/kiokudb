#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;

use ok 'KiokuDB';
use ok 'KiokuDB::Backend::Hash';

{
    package Blah;

    sub new {
        my $class = shift;
        bless {@_}, $class;
    }

    sub data { $_[0]{data} }

    package Foo;
    use base qw(Blah);

    package Bar;
    use base qw(Foo);

    package Baz;
    use base qw(Blah);

    package Qux;
    use base qw(Baz);

    package Person;
    use Moose;

    has name => ( is => "rw" );
}

use constant HAVE_CA => eval { require Class::Accessor };
use constant HAVE_OT => eval { require Object::Tiny };
use constant HAVE_OI => eval { require Object::InsideOut };

if ( HAVE_CA ) {
    eval q{
        package CA::Foo;
        use base qw(Class::Accessor);

        __PACKAGE__->mk_accessors(qw(data));
    };
}

if ( HAVE_OT ) {
    eval q{
        package OT::Foo;
        use Object::Tiny qw(data);
    }
}

if ( HAVE_OI ) {
    eval q{
        package OI::Foo;
        use Object::InsideOut;

        my @data :Field :Accessor(data) :Arg(Name => 'data');
    }
}

foreach my $format ( qw(storable json yaml) ) {
    foreach my $data ( "foo", 42, [ 1 .. 3 ], { foo => "bar" }, Person->new( name => "jello" ) ) {
        my $dir = KiokuDB->connect( hash => (
            serializer => $format,
            allow_classes => [qw(Foo)],
            allow_bases   => [qw(Baz)],
            allow_class_builders => 1,
        ));

        {
            my $s = $dir->new_scope;

            lives_ok { $dir->store( foo => Foo->new( data => $data ) ) } "can store foo";
            dies_ok  { $dir->store( bar => Bar->new( data => $data ) ) } "can't store bar";
            lives_ok { $dir->store( baz => Baz->new( data => $data ) ) } "can store baz";
            lives_ok { $dir->store( qux => Qux->new( data => $data ) ) } "can store qux";
        }

        {
            my $s = $dir->new_scope;
            is_deeply( $dir->lookup("foo"), Foo->new( data => $data ), "lookup foo" );
            is_deeply( $dir->lookup("baz"), Baz->new( data => $data ), "lookup baz" );
            is_deeply( $dir->lookup("qux"), Qux->new( data => $data ), "lookup qux" );
            ok( !$dir->exists("bar"), "bar doesn't exist" );
        }

        if ( HAVE_CA ) {
            {
                my $s = $dir->new_scope;
                lives_ok { $dir->store( ca => CA::Foo->new({ data => $data }) ) } "can store Class::Accessor";
            }

            {
                my $s = $dir->new_scope;
                is_deeply( $dir->lookup("ca"), CA::Foo->new({ data => $data }), "is_deeply" );
            }
        }

        if ( HAVE_OT ) {
            {
                my $s = $dir->new_scope;
                lives_ok { $dir->store( ot => OT::Foo->new( data => $data ) ) } "can store Object::Tiny";
            }

            {
                my $s = $dir->new_scope;
                is_deeply( $dir->lookup("ot"), OT::Foo->new( data => $data ), "is_deeply" );
            }
        }

        if ( HAVE_OI ) {
            {
                my $s = $dir->new_scope;
                lives_ok { $dir->store( oi => OI::Foo->new( data => $data ) ) } "can store Object::InsideOut";
            }

            {
                my $s = $dir->new_scope;
                is_deeply( $dir->lookup("oi")->dump, OI::Foo->new( data => $data )->dump, "is_deeply" );
            }
        }
    }
}

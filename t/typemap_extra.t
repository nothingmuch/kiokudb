#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use ok 'KiokuDB';
use ok 'KiokuDB::Backend::Hash';

{
    package KiokuDB_Test_Blah;

    sub new {
        my $class = shift;
        bless {@_}, $class;
    }

    sub data { $_[0]{data} }

    package KiokuDB_Test_Foo;
    use base qw(KiokuDB_Test_Blah);

    package KiokuDB_Test_Bar;
    use base qw(KiokuDB_Test_Foo);

    package KiokuDB_Test_Baz;
    use base qw(KiokuDB_Test_Blah);

    package KiokuDB_Test_Qux;
    use base qw(KiokuDB_Test_Baz);

    package KiokuDB_Test_Person;
    use Moose;

    has name => ( is => "rw" );
}

use constant HAVE_CA => eval { require Class::Accessor };
use constant HAVE_OT => eval { require Object::Tiny };
use constant HAVE_OI => eval { require Object::InsideOut };

if ( HAVE_CA ) {
    eval q{
        package KiokuDB_Test_CA::KiokuDB_Test_Foo;
        use base qw(Class::Accessor);

        __PACKAGE__->mk_accessors(qw(data));
    };
}

if ( HAVE_OT ) {
    eval q{
        package KiokuDB_Test_OT::KiokuDB_Test_Foo;
        use Object::Tiny qw(data);
    }
}

if ( HAVE_OI ) {
    eval q{
        package KiokuDB_Test_OI::KiokuDB_Test_Foo;
        use Object::InsideOut;

        my @data :Field :Accessor(data) :Arg(Name => 'data');
    }
}

foreach my $format ( qw(storable json yaml) ) {
    foreach my $data ( "foo", 42, [ 1 .. 3 ], { foo => "bar" }, KiokuDB_Test_Person->new( name => "jello" ) ) {
        my $dir = KiokuDB->connect( hash => (
            serializer => $format,
            allow_classes => [qw(KiokuDB_Test_Foo)],
            allow_bases   => [qw(KiokuDB_Test_Baz)],
            allow_class_builders => 1,
        ));

        {
            my $s = $dir->new_scope;

            lives_ok { $dir->store( foo => KiokuDB_Test_Foo->new( data => $data ) ) } "can store foo";
            dies_ok  { $dir->store( bar => KiokuDB_Test_Bar->new( data => $data ) ) } "can't store bar";
            lives_ok { $dir->store( baz => KiokuDB_Test_Baz->new( data => $data ) ) } "can store baz";
            lives_ok { $dir->store( qux => KiokuDB_Test_Qux->new( data => $data ) ) } "can store qux";
        }

        {
            my $s = $dir->new_scope;
            is_deeply( $dir->lookup("foo"), KiokuDB_Test_Foo->new( data => $data ), "lookup foo" );
            is_deeply( $dir->lookup("baz"), KiokuDB_Test_Baz->new( data => $data ), "lookup baz" );
            is_deeply( $dir->lookup("qux"), KiokuDB_Test_Qux->new( data => $data ), "lookup qux" );
            ok( !$dir->exists("bar"), "bar doesn't exist" );
        }

        if ( HAVE_CA ) {
            {
                my $s = $dir->new_scope;
                lives_ok { $dir->store( ca => KiokuDB_Test_CA::KiokuDB_Test_Foo->new({ data => $data }) ) } "can store Class::Accessor";
            }

            {
                my $s = $dir->new_scope;
                is_deeply( $dir->lookup("ca"), KiokuDB_Test_CA::KiokuDB_Test_Foo->new({ data => $data }), "is_deeply" );
            }
        }

        if ( HAVE_OT ) {
            {
                my $s = $dir->new_scope;
                lives_ok { $dir->store( ot => KiokuDB_Test_OT::KiokuDB_Test_Foo->new( data => $data ) ) } "can store Object::Tiny";
            }

            {
                my $s = $dir->new_scope;
                is_deeply( $dir->lookup("ot"), KiokuDB_Test_OT::KiokuDB_Test_Foo->new( data => $data ), "is_deeply" );
            }
        }

        if ( HAVE_OI ) {
            {
                my $s = $dir->new_scope;
                lives_ok { $dir->store( oi => KiokuDB_Test_OI::KiokuDB_Test_Foo->new( data => $data ) ) } "can store Object::InsideOut";
            }

            {
                my $s = $dir->new_scope;
                is_deeply( $dir->lookup("oi")->dump, KiokuDB_Test_OI::KiokuDB_Test_Foo->new( data => $data )->dump, "is_deeply" );
            }
        }
    }
}


done_testing;

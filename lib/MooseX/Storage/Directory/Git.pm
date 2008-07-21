package MooseX::Storage::Directory::Git;
use Moose;
use IPC::Cmd qw(run);
use Cwd;

extends 'MooseX::Storage::Directory';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:RLB';

has git_bin => ( is => 'ro', isa => 'Str', default => sub { return ( -e '/usr/bin/git' ) ? '/usr/bin/git' : '/usr/local/bin/git' } );
has branch  => ( is => 'rw', isa => 'Str', default => 'master' );
has cwd     => (
    is      => 'ro',
    isa     => 'Path::Class::Dir',
    coerce  => 1,
    lazy    => 1,
    default => sub { Path::Class::Dir->new( Cwd::getcwd() ) }
);

sub branches {
    my ($self) = @_;
    my $branches = $self->git_command('branch');
    my @branches = split /\s*\n\s*/, $branches;
    for (@branches) {
        s/\*//g;
        s/^\s*|\s*$//g;
    }
    return [@branches];
}

sub git_command {
    my ( $self, @args ) = @_;

    my $cwd = $self->cwd->stringify;
    my $dir = $self->dir->stringify;
    my $output;

    chdir($dir);
    run(
        command => [ $self->git_bin, @args ],
        verbose => 0,
        buffer  => \$output,
    );
    chdir($cwd);

    return $output;
}

after 'setup' => sub {
    my $self = shift;
    my $git  = $self->dir->subdir('.git');

    unless ( -d $git->stringify ) {
        $self->git_command('init');
    }
};

around 'store' => sub {
    my $next = shift;
    my ( $self, %args ) = @_;

    my $message = delete $args{'message'} || "file:$0";
    $message = qq{'$message'};
    my $branch = $self->branch;

    if ( $self->git_command( 'show-ref', $branch ) ) {
        $self->git_command( 'checkout', $branch );
    }
    else {
        $self->git_command( 'checkout', '-b', $branch );
    }

    my $uid = $self->$next(%args);

    $self->git_command( 'add', $uid );
    $self->git_command( 'commit', $uid, '-m', $message );

    my $hash = $self->git_command( 'log', '-n', '1', '--pretty=format:%H', $branch );

    return wantarray ? ( $uid, $hash ) : $uid;
};

around 'load' => sub {
    my $next = shift;
    my ( $self, %args ) = @_;

    my $checkout = delete $args{'checkout'} || 'HEAD';

    my $hash = $self->git_command( 'log', '-n', '1', '--pretty=format:%H', $checkout );
    $self->git_command( 'checkout', '-b', $args{'uuid'}, $hash );
    return $self->$next(%args);

};

after 'load' => sub {
    my ( $self, %args ) = @_;

    $self->git_command( 'checkout', $self->branch );
    $self->git_command( 'branch', '-D', $args{'uuid'} );
};

1;

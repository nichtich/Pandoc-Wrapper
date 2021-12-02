package App::Prove::Plugin::andoc;
use 5.014;
use warnings;

our $VERSION = '0.9.1';

use Pandoc;
use File::Temp qw(tempdir);
use Cwd qw(realpath);

sub load {
    my ( $class, $p ) = @_;
    my ($bin) = @{ $p->{args} };

    die "Usage: prove -Pandoc=BIN_OR_VERSION ...\n" unless defined $bin;

    if ( !-x $bin and -d pandoc_data_dir('bin') ) {
        $bin = pandoc_data_dir( 'bin', "pandoc-$bin" );
    }

    die "Pandoc executable not found: $bin\n" unless -x $bin;

    # dies if executable is not pandoc
    my $pandoc = Pandoc->new($bin);

    my $tmp = tempdir( CLEANUP => 1 );
    symlink( realpath( $pandoc->bin ), "$tmp/pandoc" )
      or die "symlinking pandoc failed!\n";

    $ENV{PATH} = "$tmp:" . $ENV{PATH};

    if ( $p->{app_prove}->{verbose} ) {
        print "# pandoc executable set to $bin\n";
    }
}

1;

__END__

=head1 NAME

App::Prove::Plugin::andoc - Select pandoc executable for tests

=head1 SYNOPSIS

  # specify executable
  prove -Pandoc=bin/pandoc-2.1.2 ...

  # specify executable in ~/.pandoc/bin/ by version number
  prove -Pandoc=2.1.2 ...

=head1 DESCRIPTION

This plugin to L<prove> temporarily modifies PATH to use a selected pandoc
executable before running tests.

=head1 SEE ALSO

See L<Pandoc::Release> to download pandoc executables.  Executables downloaded
in C<~/.pandoc/bin> can be referenced by version number.

=cut

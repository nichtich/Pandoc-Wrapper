package App::Prove::Plugin::andoc;
use strict;
use warnings;

use Pandoc;
use File::Temp qw(tempdir);
use Cwd qw(realpath);

sub load {
    my ($class, $p) = @_;
    my ($bin) = @{$p->{args}};
    
    die "Usage: prove -Pandoc=EXECUTABLE ...\n" unless defined $bin;
    die "Pandoc executable not found: $bin\n" unless -x $bin;  
    
    # dies if executable is not pandoc
    my $pandoc = Pandoc->new($bin);

    my $tmp = tempdir(CLEANUP => 1);
	symlink (realpath($pandoc->bin), "$tmp/pandoc")
        or die "symlinking pandoc failed!\n";
    
 	$ENV{PATH} = "$tmp:".$ENV{PATH};

    if ($p->{app_prove}->{verbose}) {
       print "# pandoc executable set to $bin\n";
    }
}

1;

__END__

=head1 NAME

App::Prove::Plugin::andoc - Select pandoc executable for tests

=head1 SYNOPSIS

  prove -Pandoc=my/pandoc/2.1.2 ...

=head1 DESCRIPTION

This plugin to L<prove> modifies PATH to use a selected pandoc executable
before running tests. See L<Pandoc::Release> to download pandoc executables.

=cut

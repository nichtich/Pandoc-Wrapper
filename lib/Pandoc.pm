package Pandoc;
use strict;
use warnings;
use 5.010;

=head1 NAME

Pandoc - interface to the Pandoc document converter

=cut

our $VERSION = '0.1.0';

use IPC::Run3;
use parent 'Exporter';
our @EXPORT = qw(pandoc);

our $PANDOC;

sub import {
    my ($version) = grep { $_ =~ qr/^(\d+(\.\d+)+)$/ } @_;
    if ($version) {
        $PANDOC = Pandoc->new;
        $PANDOC->require($version);
    }
    Pandoc->export_to_level(1, grep { $_ !~ qr/^(\d+(\.\d+)+)$/ } @_ );
}

sub new {
    my $out;
    my $in;

    run3 ['pandoc','-v'], \$in, \$out, \undef,
        { return_if_system_error => 1 };

    die "pandoc executable not found\n" unless
        $out and $out =~ /^pandoc (\d+(\.\d+)+)/;

    my $pandoc = bless { version => $1 }, 'Pandoc';
    $pandoc->{data_dir} = $1 if $out =~ /^Default user data directory: (.+)$/m;

    return $pandoc;
}

sub pandoc(@) { ## no critic
    $PANDOC //= eval { Pandoc->new } // 0;
    
    if (@_) {
        return $PANDOC ? $PANDOC->run(@_) : -1;
    } else {
        return $PANDOC;
    }
}

sub run {
    my $pandoc = shift;
    my $opts   = ref $_[-1] ? pop @_ : {};
    my @args   = @_;

    my $in  = $opts->{in};
    my $out = $opts->{out};
    my $err = $opts->{err};

    run3 ['pandoc', @_ ], $in, $out, $err, 
        { return_if_system_error => 1 };

    return $? == -1 ? -1 : $? >> 8;
}

sub require {
    my $pandoc = @_ < 2 
        ? $PANDOC //= Pandoc->new   # may throw
        : do { ref $_[0] ? shift : shift->new };
    my $version = shift;

    die "pandoc $version required, only found ".$pandoc->{version}."\n"
        unless $pandoc->version($version);
}

sub version {
    my $pandoc = shift;
    $pandoc = do { $PANDOC //= Pandoc->new } if $pandoc eq 'Pandoc'; 
    return unless $pandoc and $pandoc->{version};

    if (@_) {
        my $version = shift;
        die "invalid version number: $version\n"
            if $version !~ /^(\d+(\.\d+)*)$/;

        my @got = split /\./, $pandoc->{version};
        foreach my $e (split /\./, $version) {
            my $g = shift @got // 0;
            return if $e > $g;
            last   if $e < $g;
        }
    }

    return $pandoc->{version};
}

sub data_dir {
    my $pandoc = shift;
    $pandoc = do { $PANDOC //= Pandoc->new } if $pandoc eq 'Pandoc'; 
    return unless $pandoc;

    $pandoc->{data_dir};
}

1;

__END__

=encoding utf-8

=head1 SYNOPSIS

  use Pandoc;             # check at first use
  use Pandoc 1.12;        # check at compile time
  pandoc->require(1.12);  # check at run time

  # execute pandoc
  pandoc 'input.md', -o => 'output.html';
  pandoc -f => 'html', -t => 'markdown', { in => \$html, out => \$md };

  # alternative syntax
  pandoc->run('input.md', -o => 'output.html');

  # check executable
  pandoc or die "pandoc executable not found";

  # check minimum version
  pandoc->version(1.12) or die "pandoc >= 1.12 required";

  # access properties
  say "pandoc ".pandoc->version;
  say "Default user data directory: ".pandoc->data_dir;

=head1 DESCRIPTION

This module provides a Perl interface to John MacFarlane's
L<Pandoc|http://pandoc.org> document converter. The module exports function
C<pandoc> by default.

=head1 FUNCTIONS

=head2 pandoc @arguments [, \%options ]

Executes the pandoc executable with given command line arguments and
input/output/error redirected as specified with the following options:

=over

=item in

=item out

=item err

=back

The options correspond to arguments C<$stdin>, C<$stdout>, and C<$stderr> of
L<IPC::Run3>, see there for details.

The function returns C<0> on success. Otherwise it returns the the exit code of
pandoc or C<-1> if execution failed.

If called without arguments and options, returns a singleton instance of class
Pandoc with information about the executable version of pandoc or C<undef> if
no pandoc executable was found.

=head1 METHODS

=head2 new

Create a new instance of class Pandoc or throws an exception if no pandoc
executable was found. Using this constructor is not recommended unless you
explicitly want to call C<pandoc --version>, for instance because a the system
environment has changed during runtime.

=head2 run( @arguments, \%options )

Execute the pandoc executable like function C<pandoc>.

=head2 version( $version )

Return the pandoc version if it is at least as new as a given version.

=head2 require( $version )

Throw an error if the pandoc version is lower than a given version.

=head1 SEE ALSO

Use L<Pandoc:Elements> for more elaborate document processing based on Pandoc.
Other Pandoc related but outdated modules at CPAN include
L<Orze::Sources::Pandoc> and L<App::PDoc>.

=head1 COPYRIGHT AND LICENSE

Copyright 2016- Jakob Voß

GNU General Public License, Version 2

=cut

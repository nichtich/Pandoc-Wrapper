package Pandoc;
use strict;
use warnings;
use 5.010;

use utf8;

=head1 NAME

Pandoc - interface to the Pandoc document converter

=cut

our $VERSION = '0.1.0';

# Better throw all errors with croak since run() needs to throw arg error at callsite
use Carp qw[ croak ];
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

    croak "pandoc executable not found\n" unless
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

    # We shift/pop these args but want to remember what reftype they were
    my %is_ref = ( args => ('ARRAY' eq ref $_[0] ), 
                   opts => ('HASH' eq ref $_[-1]) );
    my @args   = $is_ref{args} ? @{ shift @_ } : ();
    my %opts   = $is_ref{opts} ? %{pop @_} : ();
    if ( @_ ) {
        if ( !$is_ref{args} ) {
            # default to the old behavior
            @args = @_;
        }
        elsif ( $is_ref{args} and !$is_ref{opts} and (@_ % 2 == 0) ) {
            # if args were passed by reference other arguments are options
            %opts = @_;
        }
        else {
            # passed both the args and opts by ref,
            # so other arguments don't make sense;
            # or passed args by ref and an odd-length list
            croak 'Too many or ambiguous arguments to ->run()';
        }
    }

    my $in  = $opts{in};
    my $out = $opts{out};
    my $err = $opts{err};
    $opts{return_if_system_error} = 1;
    for my $io ( qw[ in out err ] ) {
        $opts{"binmode_std$io"} //= $opts{binmode} if $opts{binmode};
        if ( 'SCALAR' eq ref $opts{$io} ) {
            next unless utf8::is_utf8(${$opts{$io}});
            $opts{"binmode_std$io"} //= ':utf8'; # or better :encoding(UTF-8) ?
        }
    }

    run3 ['pandoc', @args ], $in, $out, $err, \%opts;

    return $? == -1 ? -1 : $? >> 8;
}

sub require {
    my $pandoc = @_ < 2 
        ? $PANDOC //= Pandoc->new   # may throw
        : do { ref $_[0] ? shift : shift->new };
    my $version = shift;

    croak "pandoc $version required, only found ".$pandoc->{version}."\n"
        unless $pandoc->version($version);
}

sub version {
    my $pandoc = shift;
    $pandoc = do { $PANDOC //= Pandoc->new } if $pandoc eq 'Pandoc'; 
    return unless $pandoc and $pandoc->{version};

    if (@_) {
        my $version = shift;
        croak "invalid version number: $version\n"
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

=begin markdown

# STATUS

[![Build Status](https://travis-ci.org/nichtich/Pandoc-Wrapper.svg)](https://travis-ci.org/nichtich/Pandoc-Wrapper)
[![Coverage Status](https://coveralls.io/repos/nichtich/Pandoc-Wrapper/badge.svg)](https://coveralls.io/r/nichtich/Pandoc-Wrapper)
[![Kwalitee Score](http://cpants.cpanauthors.org/dist/Pandoc.png)](http://cpants.cpanauthors.org/dist/Pandoc)

=end markdown

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
L<Pandoc|http://pandoc.org> document converter. The module exports utility
function C<pandoc> but it can also be used as class.

=head1 FUNCTIONS

=head2 pandoc [ @arguments [, \%options ] ]

Runs the pandoc executable with given command line arguments and
input/output/error redirected, as specified with the following options:

=over

=item in

=item out

=item err

=back

The options correspond to arguments C<$stdin>, C<$stdout>, and C<$stderr> of
L<IPC::Run3>, see there for details.

If called without arguments and options, the function returns a singleton
instance of class Pandoc to access information about the executable version of
pandoc, or C<undef> if no pandoc executable was found.  If called with
arguments and/or options, the function returns C<0> on success.  Otherwise it
returns the the exit code of pandoc executable or C<-1> if execution failed.

=head1 METHODS

=head2 new

Create a new instance of class Pandoc or throw an exception if no pandoc
executable was found. Repeated use of this constructor is not recommended
unless you explicitly want to call C<pandoc --version>, for instance because a
the system environment has changed during runtime.

=head2 run( [ @arguments, \%options ] )

Execute the pandoc executable (see function C<pandoc> above).

=head2 version( [ $version ] )

Return the pandoc version if it is at least as new as a given version or if no
argument was provided.

=head2 require( $version )

Throw an error if the pandoc version is lower than a given version.

=head1 SEE ALSO

Use L<Pandoc::Elements> for more elaborate document processing based on Pandoc.
Other Pandoc related but outdated modules at CPAN include
L<Orze::Sources::Pandoc> and L<App::PDoc>.

=head1 COPYRIGHT AND LICENSE

Copyright 2016- Jakob Voß

GNU General Public License, Version 2

=cut

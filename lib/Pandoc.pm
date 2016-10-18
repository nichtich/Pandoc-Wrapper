package Pandoc;
use strict;
use warnings;
use 5.010;

use utf8;

=head1 NAME

Pandoc - interface to the Pandoc document converter

=cut

our $VERSION = '0.2.0';

use Carp 'croak';
use IPC::Run3;
use parent 'Exporter';
our @EXPORT = qw(pandoc);

our $PANDOC;
our $PANDOC_VERSION_SPEC = qr/^(\d+(\.\d+)*)$/;

sub import {
    my ($version) = grep { $_ =~ $PANDOC_VERSION_SPEC } @_;
    if ($version) {
        $PANDOC = Pandoc->new;
        $PANDOC->require($version);
    }
    Pandoc->export_to_level(1, grep { $_ !~ $PANDOC_VERSION_SPEC } @_ );
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
            croak 'Too many or ambiguous arguments';
        }
    }

    my $in  = $opts{in};
    my $out = $opts{out};
    my $err = $opts{err};
    $opts{return_if_system_error} //= 1;

    for my $io ( qw[ in out err ] ) {
        $opts{"binmode_std$io"} //= $opts{binmode} if $opts{binmode};
        if ( 'SCALAR' eq ref $opts{$io} ) {
            next unless utf8::is_utf8(${$opts{$io}});
            $opts{"binmode_std$io"} //= ':encoding(UTF-8)';
        }
    }

    run3 ['pandoc', @args ], $in, $out, $err, \%opts;

    return $? == -1 ? -1 : $? >> 8;
}

sub convert {
    my $pandoc = shift;
    $pandoc = do { $PANDOC //= Pandoc->new } if $pandoc eq 'Pandoc'; 
    return unless $pandoc;

    my $from  = shift;
    my $to    = shift;
    my $in    = shift;
    my $out   = "";
    my $err   = "";

    my $utf8 = utf8::is_utf8($in);

    my $status = $pandoc->run( [ '-f' => $from, '-t' => $to, @_ ], 
        in => \$in, out => \$out, err => \$err );
    
    croak($err || "pandoc failed with exit code $status") if $status;

    utf8::decode($out) if $utf8;

    chomp $out;
    return $out;
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

    if (@_) { # compare against given version
        my $version = shift;
        croak "invalid version number: $version\n"
            if $version !~ $PANDOC_VERSION_SPEC;

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

  # alternative syntaxes
  pandoc->run('input.md', -o => 'output.html');
  pandoc [ -f => 'html', -t => 'markdown' ], in => \$html, out => \$md;
  pandoc [ -f => 'html', -t => 'markdown' ], { in => \$html, out => \$md };

  # utility method to convert from string
  $latex = pandoc->convert( 'markdown' => 'latex', '*hello*' );

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

=head2 pandoc [ \@arguments [, %options ] ]

=head2 pandoc [ \@arguments [, \%options ] ]

Runs the pandoc executable with given command line arguments and options
and input/output/error redirected, as specified with the in/out/err
L<options|/"Options">.

Either of C<@arguments> and C<%options>, or both, may be passed as an
array or hash reference respectively. The items of the argument list to
C<pandoc()> is interpreted according to these rules:

=over

=item If the first item is an array ref and the last is a hash ref

these are C<\@arguments> and C<\%options> respectively and no other
items are allowed.

=item If the first item is an array ref and the last is I<not> a hash ref

the first item is C<\@arguments> and the remaining items if any
(of which there must be an even number) are C<%options>.

This is useful in the common case where the command line arguments are
the same over multiple calls, while the in/out/err L<options|/"Options">
are different for each call.

=item If the first item is I<not> an array ref and the last is a hash ref

the last item is C<\%options> and the preceding items if any are
C<@arguments>.

=item If I<neither> the first item is an array ref I<nor> the last is a hash ref

All the items (if any) are C<@arguments>.

=back

Note that C<\@arguments> must be the first item and C<\%options> must be
the last, but either may be an empty array/hash reference.

If called without arguments and options, the function returns a singleton
instance of class Pandoc to access information about the executable version of
pandoc, or C<undef> if no pandoc executable was found.  If called with
arguments and/or options, the function returns C<0> on success.  Otherwise it
returns the the exit code of pandoc executable or C<-1> if execution failed.

=head3 Options

=over

=item in

=item out

=item err

These options correspond to arguments C<$stdin>, C<$stdout>, and
C<$stderr> of L<IPC::Run3>, see there for details.

=item binmode_stdin

=item binmode_stdout

=item binmode_stderr

These options correspond to the like-named options to L<IPC::Run3>, see
there for details.

=item binmode

If defined any binmode_stdin/binmode_stdout/binmode_stderr option which
is undefined will be set to this value.

=back

For convenience the C<pandoc> function (I<after> checking the C<binmode>
option) checks the contents of any scalar references passed to the
in/out/err options with
L<< utf8::is_utf8()|utf8/"* C<$flag = utf8::is_utf8($string)>" >>
and sets the binmode_stdin/binmode_stdout/binmode_stderr options to
C<:encoding(UTF-8)> if the corresponding scalar is marked as UTF-8 and
the respective option is undefined. Since all pandoc executable
input/output must be UTF-8 encoded this is convenient if you run with
L<use utf8|utf8>, as you then don't need to set the binmode options at
all (L<encode nor decode|Encode>) when passing input/output scalar
references.

The C<return_if_system_error> option of L<IPC::Run3> is set to true by default;
the C<pandoc> function returns the exit code from the pandoc executable.

=head1 METHODS

=head2 new

Create a new instance of class Pandoc or throw an exception if no pandoc
executable was found. Repeated use of this constructor is not recommended
unless you explicitly want to call C<pandoc --version>, for instance because
the system environment has changed during runtime.

=head2 run( [ @arguments, \%options ] )

=head2 run( [ \@arguments, %options ] )

=head2 run( [ \@arguments, \%options ] )

Execute the pandoc executable (see function C<pandoc> above).

=head2 convert( $from => $to, $input [, @arguments ] )

Convert a string in format C<$from> to format C<$to>. Additional pandoc options
such as C<--smart> and C<--standalone> can be passed. The result is returned 
in same utf8 mode (C<utf8::is_unicode>) as the input.

=head2 version( [ $version ] )

Return the pandoc version if it is at least as new as a given version or if no
argument was provided.

=head2 require( $version )

Throw an error if the pandoc version is lower than a given version.

=head1 SEE ALSO

Use L<Pandoc::Elements> for more elaborate document processing based on Pandoc.
Other Pandoc related but outdated modules at CPAN include
L<Orze::Sources::Pandoc> and L<App::PDoc>.

=head1 AUTHOR

Jakob Voß

=head1 CONTRIBUTORS

Benct Philip Jonsson

=head1 LICENSE

GNU General Public License, Version 2

=cut

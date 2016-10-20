package Pandoc;
use strict;
use warnings;
use 5.010;

use utf8;

=head1 NAME

Pandoc - interface to the Pandoc document converter

=cut

use version 0.77; our $VERSION = version->declare('0.2.0');

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
    my ($class, %opts) = @_;
    my ($in, $out);

    my $pandoc = bless { 
        bin => $opts{bin} // 'pandoc'
    }, $class;
    
    run3 [ $pandoc->{bin},'-v'], \$in, \$out, \undef,
        { return_if_system_error => 1 };

    croak "pandoc executable not found\n" unless
        $out and $out =~ /^pandoc (\d+(\.\d+)+)/;

    $pandoc->{version} = version->parse($1);
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

    for my $io ( qw(in out err) ) {
        $opts{"binmode_std$io"} //= $opts{binmode} if $opts{binmode};
        if ( 'SCALAR' eq ref $opts{$io} ) {
            next unless utf8::is_utf8(${$opts{$io}});
            $opts{"binmode_std$io"} //= ':encoding(UTF-8)';
        }
    }

    run3 [ $pandoc->{bin}, @args ], $in, $out, $err, \%opts;

    return $? == -1 ? -1 : $? >> 8;
}

sub convert {
    my $pandoc = shift;
    my $from   = shift;
    my $to     = shift;
    my $in     = shift;
    my $out    = "";
    my $err    = "";

    my $utf8 = utf8::is_utf8($in);

    my $status = $pandoc->run( [ '-f' => $from, '-t' => $to, @_ ],
        in => \$in, out => \$out, err => \$err );

    croak($err || "pandoc failed with exit code $status") if $status;

    utf8::decode($out) if $utf8;

    chomp $out;
    return $out;
}

sub require {
    my ($pandoc, $version) = @_;
    $pandoc = do { $PANDOC //= Pandoc->new } if $pandoc eq 'Pandoc'; 
    croak "pandoc $version required, only found ".$pandoc->{version}."\n"
        unless $pandoc->version($version);
    return $pandoc;
}

sub version {
    my $pandoc = shift;
    return unless $pandoc and $pandoc->{version};

    # compare against given version
    if (@_) {
        my $version = eval { version->parse($_[0]) } or
            croak "Invalid version format: $_[0]";
        return if $version > $pandoc->{version};
    }

    return $pandoc->{version};
}

sub data_dir {
    $_[0]->{data_dir};
}

sub _help { # not documented. may change to return structured data
    my ($pandoc) = @_;

	unless (defined $pandoc->{help}) {
		my $help;
    	$pandoc->run('--help', { out => \$help });
		for my $inout (qw(Input Output)) {
			$help =~ /^$inout formats:\s+([a-z_0-9,\+\s*]+)/m;
			$pandoc->{lc($inout).'_formats'} = [ split /,\s+|\s+/, $1 ]
		}
	    $pandoc->{help} = $help;
    }

	$pandoc->{help} 
}

sub input_formats {
    my ($pandoc) = @_;
	$pandoc->_help;
    @{$pandoc->{input_formats}};
}

sub output_formats {
    my ($pandoc) = @_;
	$pandoc->_help;
    @{$pandoc->{output_formats}};
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
  Pandoc->require(1.12);  # check at run time

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

=head2 pandoc [ \@arguments [, %options | \%options ] ]

If called without arguments and options, the function returns a singleton
instance of class Pandoc to execute L<methods|/METHODS>, or C<undef> if no
pandoc executable was found. Otherwise runs the pandoc executable with given
command line arguments. Additional options control input, output, and error
stream as described below.

Arguments and options can be passed as plain array/hash or as (possibly empty)
reference but one of them must be a reference if both are provided or if one of
both is empty.

  pandoc @arguments, { ... };    # ok
  pandoc [ ... ], %options;      # ok

  pandoc @arguments, %options;   # not ok!

If called with arguments and/or options, the function returns C<0> on success.
Otherwise it returns the the exit code of pandoc executable or C<-1> if
execution failed.

=head3 Options

=over

=item in / out / err

These options correspond to arguments C<$stdin>, C<$stdout>, and
C<$stderr> of L<IPC::Run3>, see there for details.

=item binmode_stdin / binmode_stdout / binmode_stderr

These options correspond to the like-named options to L<IPC::Run3>, see
there for details.

=item binmode

If defined any binmode_stdin/binmode_stdout/binmode_stderr option which
is undefined will be set to this value.

=item return_if_system_error

Set to true by default to return the exit code of pandoc executable. 

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

=head1 METHODS

=head2 new( [ %options ] )

Create a new instance of class Pandoc or throw an exception if no pandoc
executable was found. Repeated use of this constructor is not recommended
because C<pandoc --version> is called onec for every instance. Possible options
include:

=head3 Options

=over

=item bin

pandoc executable (C<pandoc> by default)

=back

=head2 run( [ @arguments, \%options ] )

=head2 run( [ \@arguments [ %options | \%options ] ] )

Execute the pandoc executable (see function C<pandoc> above).

=head2 require( $minimum_version )

Return the Pandoc instance if its version number is at least as high as the
given minimum version. Throw an error otherwise.  This method can also be
called as constructor: C<< Pandoc->require(...) >> is equivalent to C<<
pandoc->require >> but throws a more meaningful error message if no pandoc
executable was found.

=head2 convert( $from => $to, $input [, @arguments ] )

Convert a string in format C<$from> to format C<$to>. Additional pandoc options
such as C<--smart> and C<--standalone> can be passed. The result is returned
in same utf8 mode (C<utf8::is_unicode>) as the input.

=head2 version( [ $minimum_version ] )

Return the pandoc version as L<version> object. Returns undef if the version is
lower than a given minimum version.

=head2 data_dir

Return the default data directory (only available since Pandoc 1.11).

=head2 input_formats

Return a list of supported input formats.

=head2 output_formats

Return a list of supported output formats.

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

package Pandoc;
use strict;
use warnings;
use 5.010;

use utf8;

=head1 NAME

Pandoc - interface to the Pandoc document converter

=cut

use version 0.77; our $VERSION = version->declare('0.3.0');

use Carp 'croak';
use File::Which;
use IPC::Run3;
use parent 'Exporter';
our @EXPORT = qw(pandoc);

our $PANDOC;
our $PANDOC_VERSION_SPEC = qr/^(\d+(\.\d+)*)$/;

sub import {
    shift;

    if (@_ and $_[0] =~ /^\d+/) {
        $PANDOC //= Pandoc->new;
        $PANDOC->require(shift);
    }
    $PANDOC //= Pandoc->new(@_) if @_;

    Pandoc->export_to_level(1, 'pandoc');
}

sub VERSION {
    shift;
    $PANDOC //= Pandoc->new;
    $PANDOC->require(shift) if @_;
    $PANDOC->version;
}

sub new {
    my $pandoc = bless { }, shift;

    my $bin = (@_ and $_[0] !~ /^-./) ? shift : 'pandoc';
    $pandoc->{bin} = which($bin);

    $pandoc->{arguments} = [];
    $pandoc->arguments(@_) if @_;

    my ($in, $out);

    if ($pandoc->{bin}) {
        run3 [ $pandoc->{bin},'-v'], \$in, \$out, \undef,
            { return_if_system_error => 1 };
    }
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

    my $args = 'ARRAY' eq ref $_[0] ? \@{shift @_} : undef; # \@args [ ... ]
    my $opts = 'HASH' eq ref $_[-1] ? \%{pop @_} : undef;   # [ ... ] \%opts
    
    if ( @_ ) {
        if ( !$args ) {                                     # @args
            if ($_[0] =~ /^-/) {
                $args = \@_;
            } else {                                        # %opts
                $opts = { @_ };
            }
        }
        elsif ( $args and !$opts and (@_ % 2 == 0) ) {      # \@args [, %opts ]
            $opts = { @_ };
        }
        else {
            # passed both the args and opts by ref,
            # so other arguments don't make sense;
            # or passed args by ref and an odd-length list
            croak 'Too many or ambiguous arguments';
        }
    }

    $args //= [];
    $opts //= {};

    for my $io ( qw(in out err) ) {
        $opts->{"binmode_std$io"} //= $opts->{binmode} if $opts->{binmode};
        if ( 'SCALAR' eq ref $opts->{$io} ) {
            next unless utf8::is_utf8(${$opts->{$io}});
            $opts->{"binmode_std$io"} //= ':encoding(UTF-8)';
        }
    }

    $opts->{return_if_system_error} //= 1;
    $args = [ $pandoc->{bin}, @{$pandoc->{arguments}}, @$args ];

    run3 $args, $opts->{in}, $opts->{out}, $opts->{err}, $opts;    

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

sub bin {
    my $pandoc = shift;
    if (@_) {
        my $new = Pandoc->new(shift);
        $pandoc->{$_} = $new->{$_} for (qw(version bin data_dir));
    }
    $pandoc->{bin};
}

sub arguments {
    my $pandoc = shift;
    if (@_) {
        my $args = 'ARRAY' eq ref $_[0] ? shift : \@_;
        croak "first default argument must be an -option"
            if @$args and $args->[0] !~ /^-./;
        $pandoc->{arguments} = $args;
    }
    @{$pandoc->{arguments}};
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
  say pandoc->bin." ".pandoc->version;
  say "Default user data directory: ".pandoc->data_dir;

  # create an instance with default arguments
  my $md2latex = Pandoc->new(qw(-f markdown -t latex --smart));
  $md2latex->run({ in => \$markdown, out => \$latex });

  # set default arguments on compile time
  use Pandoc qw(-t latex);
  use Pandoc qw(/ur/bin/pandoc --smart);
  use Pandoc qw(1.16 --smart);

=head1 DESCRIPTION

This module provides a Perl interface to John MacFarlane's
L<Pandoc|http://pandoc.org> document converter. The module exports utility
function C<pandoc> but it can also be used as class.

=head1 FUNCTIONS

=head1 pandoc

If called without parameters, this function returns a singleton instance of
class Pandoc to execute L<methods|/METHODS>, or C<undef> if no pandoc
executable was found. 

=head2 pandoc ... 

If called with parameters, this functions runs the pandoc executable. Arguments
are passed as command line arguments and options control input, output, and
error stream as described below. Returns C<0> on success.  Otherwise returns
the the exit code of pandoc executable or C<-1> if execution failed.  Arguments
and options can be passed as plain array/hash or as (possibly empty) reference
in the following ways:

  pandoc @arguments, \%options;     # ok
  pandoc \@arguments, %options;     # ok
  pandoc \@arguments, \%options;    # ok
  pandoc @arguments;                # ok, if first of @arguments starts with '-'
  pandoc %options;                  # ok, if %options is not empty

  pandoc @arguments, %options;      # not ok!

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

=head2 new( [ $executable ] [, @arguments ] )

Create a new instance of class Pandoc or throw an exception if no pandoc
executable was found. The first argument, if given and not starting with C<->,
can be used to set the pandoc executable (C<pandoc> by default). Additional
arguments are passed to the executable on each run.

Repeated use of this constructor with same arguments is not recommended because
C<pandoc --version> is called for every new instance.

=head2 run( ... )

Execute the pandoc executable with default arguments and optional additional
arguments and options. See L<<function C<pandoc>|/FUNCTIONS>> for usage.

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

=head2 bin( [ $executable ] )

Return or set the pandoc executable.

=head2 arguments( [ @arguments | \@arguments )

Return or set a list of default arguments.

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

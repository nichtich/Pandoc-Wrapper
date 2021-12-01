package Pandoc;
use 5.014;
use warnings;

use utf8;

=head1 NAME

Pandoc - wrapper for the mighty Pandoc document converter

=cut

our $VERSION = '0.9.1';

use Pandoc::Version;
use Pandoc::Error;
use File::Which;
use File::Spec::Functions 'catdir';
use IPC::Run3;
use parent 'Exporter';
our @EXPORT = qw(pandoc pandoc_data_dir);

our $PANDOC;
our $PANDOC_PATH ||= $ENV{PANDOC_PATH} || 'pandoc';

sub import {
    shift;

    if ( @_ and $_[0] =~ /^[v0-9.<>=!, ]+$/ ) {
        $PANDOC //= Pandoc->new;
        $PANDOC->require(shift);
    }
    $PANDOC //= Pandoc->new(@_) if @_;

    Pandoc->export_to_level( 1, 'pandoc' );
}

sub VERSION {
    shift;
    $PANDOC //= Pandoc->new;
    $PANDOC->require(shift) if @_;
    $PANDOC->version;
}

sub new {
    my $pandoc = bless {}, shift;

    my $bin = ( @_ and $_[0] !~ /^-./ ) ? shift : $PANDOC_PATH;

    my $bin_from_version = pandoc_data_dir( "bin", "pandoc-$bin" );
    if ( !-x $bin && $bin =~ /^\d+(\.\d+)*$/ && -x $bin_from_version ) {
        $pandoc->{bin} = $bin_from_version;
    }
    else {
        $pandoc->{bin} = which($bin);
    }

    $pandoc->{arguments} = [];
    $pandoc->arguments(@_) if @_;

    my ( $in, $out, $err );

    if ( $pandoc->{bin} ) {
        run3 [ $pandoc->{bin}, '-v' ], \$in, \$out, \$err,
          { return_if_system_error => 1 };
    }
    unless ( $out and $out =~ /^[^ ]+ (\d+(\.\d+)+)/ ) {
        Pandoc::Error->throw(
            message => "pandoc executable not found",
            out     => $out,
            err     => $err,
        );
    }

    $pandoc->{version} = Pandoc::Version->new($1);
    $pandoc->{data_dir} = $1 if $out =~ /^Default user data directory: (.+)$/m;

    # before pandoc supported --list-highlight-languages
    if ( $out =~ /^Syntax highlighting is supported/m ) {
        $pandoc->{highlight_languages} =
          [ map { split /\s*,\s*/, $_ } ( $out =~ /^    (.+)$/mg ) ];
    }

    my %libs;
    my $LIBRARY_VERSION = qr/\s+(\pL\w*(?:-\pL\w*)*)\s+(\d+(?:\.\d+)*),?/;
    if ( $out =~ /^Compiled with($LIBRARY_VERSION+)/m ) {
        %libs = $1 =~ /$LIBRARY_VERSION/g;
        for my $name ( keys %libs ) {
            $libs{$name} = Pandoc::Version->new( $libs{$name} );
        }
    }
    $pandoc->{libs} = \%libs;

    return $pandoc;
}

sub pandoc(@) {    ## no critic
    $PANDOC //= eval { Pandoc->new } // 0;

    if (@_) {
        return $PANDOC ? $PANDOC->run(@_) : -1;
    }
    else {
        return $PANDOC;
    }
}

sub run {
    my $pandoc = shift;

    my $args = 'ARRAY' eq ref $_[0] ? \@{ shift @_ } : undef;   # \@args [ ... ]
    my $opts = 'HASH' eq ref $_[-1] ? \%{ pop @_ }   : undef;   # [ ... ] \%opts

    if (@_) {
        if ( !$args ) {                                         # @args
            if ( $_[0] =~ /^-/ or $opts or @_ % 2 ) {
                $args = \@_;
            }
            else {                                              # %opts
                $opts = {@_};
            }
        }
        elsif ( $args and !$opts and ( @_ % 2 == 0 ) ) {    # \@args [, %opts ]
            $opts = {@_};
        }
        else {
            # passed both the args and opts by ref,
            # so other arguments don't make sense;
            # or passed args by ref and an odd-length list
            Pandoc::Error->throw('Too many or ambiguous arguments');
        }
    }

    $args //= [];
    $opts //= {};

    for my $io (qw(in out err)) {
        $opts->{"binmode_std$io"} //= $opts->{binmode} if $opts->{binmode};
        if ( 'SCALAR' eq ref $opts->{$io} ) {
            next unless utf8::is_utf8( ${ $opts->{$io} } );
            $opts->{"binmode_std$io"} //= ':encoding(UTF-8)';
        }
    }

    my $throw = $opts->{throw} || !( $opts->{return_if_system_error} // 1 );
    $opts->{out} //= \( my $out );
    $opts->{err} //= \( my $err );

    $opts->{return_if_system_error} = 1;
    run3 [ $pandoc->{bin}, @{ $pandoc->{arguments} }, @$args ],
      $opts->{in}, $opts->{out}, $opts->{err}, $opts;

    my $status = $? == -1 ? -1 : $? >> 8;

    if ( $status && $throw ) {
        Pandoc::Error->throw(
            system  => $!,
            out     => ${ $opts->{out} },
            err     => ${ $opts->{err} },
            status  => $status,
            message => ${ $opts->{err} } || 'pandoc execution failed'
        );
    }
    else {
        $status;
    }
}

sub convert {
    my $pandoc = shift;
    my $from   = shift;
    my $to     = shift;
    my $in     = shift;
    my $out    = "";

    my $utf8 = utf8::is_utf8($in);

    $pandoc->run(
        [ @_, '-f' => $from, '-t' => $to, '-o' => '-' ],
        { in => \$in, out => \$out, throw => 1 }
    );

    utf8::decode($out) if $utf8;

    chomp $out;
    return $out;
}

sub parse {
    my $pandoc = shift;
    my $format = shift;
    my $json   = "";

    if ( $format eq 'json' ) {
        $json = shift;
    }
    else {
        $pandoc->require('1.12.1');
        $json = $pandoc->convert( $format => 'json', @_ );
    }

    require Pandoc::Elements;
    Pandoc::Elements::pandoc_json($json);
}

sub file {
    my $pandoc = shift;
    $pandoc->require('1.12.1');

    my @args = ( @_, '-t' => 'json', '-o' => '-' );
    $pandoc->run( \@args, out => \( my $json ), throw => 1 );

    require Pandoc::Elements;
    Pandoc::Elements::pandoc_json($json);
}

sub require {
    my $pandoc = shift;
    $pandoc = do { $PANDOC //= Pandoc->new } if $pandoc eq 'Pandoc';
    unless ( $pandoc->version(@_) ) {
        Pandoc::Error->throw(
            message => "pandoc $_[0] required, only found "
              . $pandoc->{version},
            version => $pandoc->{version},
            require => $_[0],
        );
    }
    return $pandoc;
}

sub version {
    my $pandoc = shift or return;
    my $version = $pandoc->{version} or return;

    # compare against given version
    return if @_ and not $version->fulfills(@_);

    return $version;
}

sub data_dir {
    catdir( shift->{data_dir}, @_ );
}

sub pandoc_data_dir {
    if ( $^O eq 'MSWin32' ) {
        catdir( $ENV{APPDATA}, 'pandoc', @_ );
    }
    else {
        catdir( $ENV{HOME}, '.pandoc', @_ );
    }
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
        Pandoc::Error->throw("first default argument must be an -option")
          if @$args and $args->[0] !~ /^-./;
        $pandoc->{arguments} = $args;
    }
    @{ $pandoc->{arguments} };
}

sub _list {
    my ( $pandoc, $which ) = @_;
    if ( !$pandoc->{$which} ) {
        if ( $pandoc->version('1.18') ) {
            my $list    = "";
            my $command = $which;
            $command =~ s/_/-/g;
            $pandoc->run( "--list-$command", { out => \$list } );
            $pandoc->{$which} = [ split /\n/, $list ];
        }
        elsif ( !defined $pandoc->{help} ) {
            my $help;
            $pandoc->run( '--help', { out => \$help } );
            for my $inout (qw(Input Output)) {
                $help =~ /^$inout formats:\s+([a-z_0-9,\+\s*]+)/m or next;
                $pandoc->{ lc($inout) . '_formats' } =
                  [ split /\*?,\s+|\*?\s+/, $1 ];
            }
            $pandoc->{help} = $help;
        }
    }
    @{ $pandoc->{$which} // [] };
}

sub input_formats {
    $_[0]->_list('input_formats');
}

sub output_formats {
    $_[0]->_list('output_formats');
}

sub highlight_languages {
    $_[0]->_list('highlight_languages');
}

sub extensions {
    my $pandoc = shift;
    my $format = shift // '';
    my $out    = "";
    my %ext;

    if ( $pandoc->version < 1.18 ) {
        warn "pandoc >= 1.18 required for --list-extensions\n";
    }
    else {
        if ($format) {
            if ( $format =~ /^[a-z0-9_]$/ and $pandoc->version >= '2.0.6' ) {
                $format = "=$format";
            }
            else {
                warn "ignoring format argument to Pandoc->extensions\n";
                $format = '';
            }
        }
        $pandoc->run( "--list-extensions$format", { out => \$out } );
        %ext = map {
            $_ =~ /^([+-]?)\s*([^-+ ]+)\s*([+-]?)$/;
            ( $2 => ( $1 || $3 ) eq '+' ? 1 : 0 );
        } split /\n/, $out;
    }

    %ext;
}

sub libs {
    $_[0]->{libs};
}

sub symlink {
    my $self = shift;
    my ( $name, %opts ) = @_ % 2 ? @_ : ( '', @_ );

    if ( '' eq $name // '' ) {
        $name = pandoc_data_dir( 'bin', 'pandoc' );
    }
    elsif ( -d $name ) {
        $name = "$name/pandoc";
    }

    my $bin = $self->bin;

    unlink $name if -l $name;
    if ( symlink $bin, $name ) {
        say "symlinked $name -> $bin" if $opts{verbose};
        $self->bin($name);
    }
    else {
        die "failed to create symlink $name -> $bin\n";
    }

    $self;
}

1;

__END__

=encoding utf-8

=begin markdown

# STATUS

[![Linux Build Status](https://travis-ci.org/nichtich/Pandoc-Wrapper.svg)](https://travis-ci.org/nichtich/Pandoc-Wrapper)
[![Windows Build Status](https://ci.appveyor.com/api/projects/status/8p68qdqv72to633d?svg=true)](https://ci.appveyor.com/project/nichtich/pandoc-wrapper)
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

  # check executable
  pandoc or die "pandoc executable not found";

  # check minimum version
  pandoc->version > 1.12 or die "pandoc >= 1.12 required";

  # access properties
  say pandoc->bin." ".pandoc->version;
  say "Default user data directory: ".pandoc->data_dir;
  say "Compiled with: ".join(", ", keys %{ pandoc->libs });
  say pandoc->libs->{'highlighting-kate'};

  # create a new instance with default arguments
  my $md2latex = Pandoc->new(qw(-f markdown -t latex --number-sections));
  $md2latex->run({ in => \$markdown, out => \$latex });

  # create a new instance with selected executable
  my $pandoc = Pandoc->new('bin/pandoc');
  my $pandoc = Pandoc->new('2.1'); # use ~/.pandoc/bin/pandoc-2.1 if available

  # set default arguments on compile time
  use Pandoc qw(-t latex);
  use Pandoc qw(/usr/bin/pandoc --number-sections);
  use Pandoc qw(1.16 --number-sections);

  # utility method to convert from string
  $latex = pandoc->convert( 'markdown' => 'latex', '*hello*' );

  # utility methods to parse abstract syntax tree (requires Pandoc::Elements)
  $doc = pandoc->parse( markdown => '*hello* **world!**' );
  $doc = pandoc->file( 'example.md' );
  $doc = pandoc->file;  # read Markdown from STDIN

=head1 DESCRIPTION

This module provides a Perl wrapper for John MacFarlane's
L<Pandoc|http://pandoc.org> document converter. 

=head1 INSTALLATION

This module requires the Perl programming language (>= version 5.14) as
included in most Unix operating systems by default. The recommended method to
install Perl modules is C<cpanm> (see its L<install
instructions|https://metacpan.org/pod/App::cpanminus#INSTALLATION> if needed):

  cpanm Pandoc

Installing instruction for Pandoc itself are given L<at Pandoc
homepage|http://pandoc.org/installing.html>. On Debian-based systems this
module and script L<pandoc-version> can be used to install and update the
pandoc executable with L<Pandoc::Release>:

  pandoc-version install

Then add C<~/.pandoc/bin> to your C<PATH> or copy C<~/.pandoc/bin/pandoc> to
a location where it can be executed.

=head1 USAGE

The utility function L<pandoc|/pandoc> is exported, unless the module is
imported with an empty list (C<use Pandoc ();>). Importing this module with a
version number or a more complex version requirenment (e.g. C<use Pandoc
1.13;> or C<< use Pandoc '>= 1.6, !=1.7 >>) will check version number of
pandoc executable instead of version number of this module (see
C<$Pandoc::VERSION> for the latter). Additional import arguments can be passed
to set the executable location and default arguments of the global Pandoc
instance used by function pandoc.

=head1 FUNCTIONS

=head2 pandoc

If called without parameters, this function returns a global instance of class
Pandoc to execute L<methods|/METHODS>, or C<undef> if no pandoc executable was
found. The location and/or name of pandoc executable can be set with
environment variable C<PANDOC_PATH> (set to the string C<pandoc> by default).

=head2 pandoc( ... )

If called with parameters, this functions runs the pandoc executable configured
at the global instance of class Pandoc (C<< pandoc->bin >>). Arguments (given
as array or array reference) are passed as pandoc command line arguments.
Additional options (given as hash or has reference) can control input, output,
and error stream:

  pandoc @arguments, \%options;     # ok
  pandoc \@arguments, %options;     # ok
  pandoc \@arguments, \%options;    # ok
  pandoc @arguments;                # ok, if first of @arguments starts with '-'
  pandoc %options;                  # ok, if %options is not empty

  pandoc @arguments, %options;      # not ok!

Returns C<0> on success. On error returns the exit code of pandoc executable or
C<-1> if execution failed. If option C<throw> is set, a L<Pandoc::Error> is
thrown instead. The following options are recognized:

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

=item throw

Throw a L<Pandoc::Error> instead returning the exit code on error. Disabled by
default.

=item return_if_system_error

Set to negation of option C<throw> by default.

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

=head2 pandoc_data_dir( [ @subdirs ] [ $file ] )

Returns the default pandoc data directory which is directory C<.pandoc> in the
home directory for Unix or C<pandoc> directory in C<%APPDATA%> for Windows.
Optional arguments can be given to refer to a specific subdirectory or file.

=head1 METHODS

=head2 new( [ $executable | $version ] [, @arguments ] )

Create a new instance of class Pandoc or throw an exception if no pandoc
executable was found.  The first argument, if given and not starting with C<->,
can be used to set the pandoc executable (C<pandoc> by default).  If a version
is specified the executable is also searched in C<~/.pandoc/bin>, e.g.
C<~/.pandoc/bin/pandoc-2.0> for version C<2.0>.  Additional arguments are
passed to the executable on each run.

Repeated use of this constructor with same arguments is not recommended because
C<pandoc --version> is called for every new instance.

=head2 run( ... )

Execute the pandoc executable with default arguments and optional additional
arguments and options. See L<function pandoc|/pandoc> for usage.

=head2 convert( $from => $to, $input [, @arguments ] )

Convert a string in format C<$from> to format C<$to>. Additional pandoc options
such as C<-N> and C<--standalone> can be passed. The result is returned
in same utf8 mode (C<utf8::is_unicode>) as the input. To convert from file to
string use method C<pandoc>/C<run> like this and set input/output format via
standard pandoc arguments C<-f> and C<-t>:

  pandoc->run( $filename, @arguments, { out => \$string } );

=head2 parse( $from => $input [, @arguments ] )

Parse a string in format C<$from> to a L<Pandoc::Document> object. Additional
pandoc options such as C<-N> and C<--normalize> can be passed. This method
requires at least pandoc version 1.12.1 and the Perl module L<Pandoc::Elements>.

The reverse action is possible with method C<to_pandoc> of L<Pandoc::Document>.
Additional shortcut methods such as C<to_html> are available:

  $html = pandoc->parse( 'markdown' => '# A *section*' )->to_html;

Method C<convert> should be preferred for simple conversions unless you want to
modify or inspect the parsed document in between.

=head2 file( [ $filename [, @arguments ] ] )

Parse from a file (or STDIN) to a L<Pandoc::Document> object. Additional pandoc
options can be passed, for instance use HTML input format (C<@arguments = qw(-f
html)>) instead of default markdown. This method requires at least pandoc
version 1.12.1 and the Perl module L<Pandoc::Elements>.

=head2 require( $version_requirement )

Return the Pandoc instance if its version number fulfills a given version
requirement. Throw an error otherwise.  Can also be called as constructor:
C<< Pandoc->require(...) >> is equivalent to C<< pandoc->require >> but
throws a more meaningful error message if no pandoc executable was found.

=head2 version( [ $version_requirement ] )

Return the pandoc version as L<Pandoc::Version> object.  If a version
requirement is given, the method returns undef if the pandoc version does not
fulfill this requirement.  To check whether pandoc is available with a given
minimal version use one of:

  Pandoc->require( $minimum_version)                # true or die
  pandoc and pandoc->version( $minimum_version )    # true or false

=head2 bin( [ $executable ] )

Return or set the pandoc executable. Setting an new executable also updates
version and data_dir by calling C<pandoc --version>.

=head2 symlink( [ $name ] [ verbose => 0|1 ] )

Create a symlink with given name to the executable and change executable to the
symlink location afterwards. An existing symlink is replaced. If C<$name> is an
existing directory, the symlink will be named C<pandoc> in there. This makes
most sense if the directory is listed in environment variable C<$PATH>. If the
name is omitted or an empty string, symlink is created in subdirectory C<bin>
of pandoc data directory.

=head2 arguments( [ @arguments | \@arguments )

Return or set a list of default arguments.

=head2 data_dir( [ @subdirs ] [ $file ] )

Return the stated default data directory, introduced with Pandoc 1.11.  Use
function C<pandoc_data_dir> alternatively to get the expected directory without
calling Pandoc executable.

=head2 input_formats

Return a list of supported input formats.

=head2 output_formats

Return a list of supported output formats.

=head2 highlight_languages

Return a list of programming languages which syntax highlighting is supported
for (via Haskell library highlighting-kate).

=head2 extensions( [ $format ] )

Return a hash of extensions mapped to whether they are enabled by default.
This method is only available since Pandoc 1.18 and the optional format
argument since Pandoc 2.0.6.

=head2 libs

Return a hash mapping the names of Haskell libraries compiled into the
pandoc executable to L<Pandoc::Version> objects.

=head1 SEE ALSO

This package includes L<Pandoc::Version> to compare Pandoc version numbers,
L<Pandoc::Release> to get Pandoc releases from GitHub, and
L<App::Prove::Plugin::andoc> to run tests with selected Pandoc executables.

See L<Pandoc::Elements> for a Perl interface to the abstract syntax tree of
Pandoc documents for more elaborate document processing.

See L<Pod::Pandoc> to parse Plain Old Documentation format (L<perlpod>) for
processing with Pandoc.

See L<Pandoc wrappers and interfaces|https://github.com/jgm/pandoc/wiki/Pandoc-wrappers-and-interfaces>
in the Pandoc GitHub Wiki for a list of wrappers in other programming
languages.

Other Pandoc related but outdated modules at CPAN include
L<Orze::Sources::Pandoc> and L<App::PDoc>.

=head1 AUTHOR

Jakob Voß

=head1 CONTRIBUTORS

Benct Philip Jonsson

=head1 LICENSE

European Union Public Licence v. 1.2 (EUPL-1.2)

=cut

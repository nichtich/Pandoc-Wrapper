# NAME

Pandoc - wrapper for the mighty Pandoc document converter

# STATUS

[![Linux Build Status](https://travis-ci.org/nichtich/Pandoc-Wrapper.svg)](https://travis-ci.org/nichtich/Pandoc-Wrapper)
[![Windows Build Status](https://ci.appveyor.com/api/projects/status/8p68qdqv72to633d?svg=true)](https://ci.appveyor.com/project/nichtich/pandoc-wrapper)
[![Coverage Status](https://coveralls.io/repos/nichtich/Pandoc-Wrapper/badge.svg)](https://coveralls.io/r/nichtich/Pandoc-Wrapper)
[![Kwalitee Score](http://cpants.cpanauthors.org/dist/Pandoc.png)](http://cpants.cpanauthors.org/dist/Pandoc)

# SYNOPSIS

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

# DESCRIPTION

This module provides a Perl wrapper for John MacFarlane's
[Pandoc](http://pandoc.org) document converter. 

# INSTALLATION

This module requires the Perl programming language (>= version 5.14) as
included in most Unix operating systems by default. The recommended method to
install Perl modules is `cpanm` (see its [install
instructions](https://metacpan.org/pod/App::cpanminus#INSTALLATION) if needed):

    cpanm Pandoc

Installing instruction for Pandoc itself are given [at Pandoc
homepage](http://pandoc.org/installing.html). On Debian-based systems this
module and script [pandoc-version](https://metacpan.org/pod/pandoc-version) can be used to install and update the
pandoc executable with [Pandoc::Release](https://metacpan.org/pod/Pandoc%3A%3ARelease):

    pandoc-version install

Then add `~/.pandoc/bin` to your `PATH` or copy `~/.pandoc/bin/pandoc` to
a location where it can be executed.

# USAGE

The utility function [pandoc](#pandoc) is exported, unless the module is
imported with an empty list (`use Pandoc ();`). Importing this module with a
version number or a more complex version requirenment (e.g. `use Pandoc
1.13;` or `use Pandoc '>= 1.6, !=1.7`) will check version number of
pandoc executable instead of version number of this module (see
`$Pandoc::VERSION` for the latter). Additional import arguments can be passed
to set the executable location and default arguments of the global Pandoc
instance used by function pandoc.

# FUNCTIONS

## pandoc

If called without parameters, this function returns a global instance of class
Pandoc to execute [methods](#methods), or `undef` if no pandoc executable was
found. The location and/or name of pandoc executable can be set with
environment variable `PANDOC_PATH` (set to the string `pandoc` by default).

## pandoc( ... )

If called with parameters, this functions runs the pandoc executable configured
at the global instance of class Pandoc (`pandoc->bin`). Arguments (given
as array or array reference) are passed as pandoc command line arguments.
Additional options (given as hash or has reference) can control input, output,
and error stream:

    pandoc @arguments, \%options;     # ok
    pandoc \@arguments, %options;     # ok
    pandoc \@arguments, \%options;    # ok
    pandoc @arguments;                # ok, if first of @arguments starts with '-'
    pandoc %options;                  # ok, if %options is not empty

    pandoc @arguments, %options;      # not ok!

Returns `0` on success. On error returns the exit code of pandoc executable or
`-1` if execution failed. If option `throw` is set, a [Pandoc::Error](https://metacpan.org/pod/Pandoc%3A%3AError) is
thrown instead. The following options are recognized:

- in / out / err

    These options correspond to arguments `$stdin`, `$stdout`, and
    `$stderr` of [IPC::Run3](https://metacpan.org/pod/IPC%3A%3ARun3), see there for details.

- binmode\_stdin / binmode\_stdout / binmode\_stderr

    These options correspond to the like-named options to [IPC::Run3](https://metacpan.org/pod/IPC%3A%3ARun3), see
    there for details.

- binmode

    If defined any binmode\_stdin/binmode\_stdout/binmode\_stderr option which
    is undefined will be set to this value.

- throw

    Throw a [Pandoc::Error](https://metacpan.org/pod/Pandoc%3A%3AError) instead returning the exit code on error. Disabled by
    default.

- return\_if\_system\_error

    Set to negation of option `throw` by default.

For convenience the `pandoc` function (_after_ checking the `binmode`
option) checks the contents of any scalar references passed to the
in/out/err options with
[utf8::is\_utf8()](https://metacpan.org/pod/utf8#flag-utf8::is_utf8-string)
and sets the binmode\_stdin/binmode\_stdout/binmode\_stderr options to
`:encoding(UTF-8)` if the corresponding scalar is marked as UTF-8 and
the respective option is undefined. Since all pandoc executable
input/output must be UTF-8 encoded this is convenient if you run with
[use utf8](https://metacpan.org/pod/utf8), as you then don't need to set the binmode options at
all ([encode nor decode](https://metacpan.org/pod/Encode)) when passing input/output scalar
references.

## pandoc\_data\_dir( \[ @subdirs \] \[ $file \] )

Returns the default pandoc data directory which is directory `.pandoc` in the
home directory for Unix or `pandoc` directory in `%APPDATA%` for Windows.
Optional arguments can be given to refer to a specific subdirectory or file.

# METHODS

## new( \[ $executable | $version \] \[, @arguments \] )

Create a new instance of class Pandoc or throw an exception if no pandoc
executable was found.  The first argument, if given and not starting with `-`,
can be used to set the pandoc executable (`pandoc` by default).  If a version
is specified the executable is also searched in `~/.pandoc/bin`, e.g.
`~/.pandoc/bin/pandoc-2.0` for version `2.0`.  Additional arguments are
passed to the executable on each run.

Repeated use of this constructor with same arguments is not recommended because
`pandoc --version` is called for every new instance.

## run( ... )

Execute the pandoc executable with default arguments and optional additional
arguments and options. See [function pandoc](#pandoc) for usage.

## convert( $from => $to, $input \[, @arguments \] )

Convert a string in format `$from` to format `$to`. Additional pandoc options
such as `-N` and `--standalone` can be passed. The result is returned
in same utf8 mode (`utf8::is_unicode`) as the input. To convert from file to
string use method `pandoc`/`run` like this and set input/output format via
standard pandoc arguments `-f` and `-t`:

    pandoc->run( $filename, @arguments, { out => \$string } );

## parse( $from => $input \[, @arguments \] )

Parse a string in format `$from` to a [Pandoc::Document](https://metacpan.org/pod/Pandoc%3A%3ADocument) object. Additional
pandoc options such as `-N` and `--normalize` can be passed. This method
requires at least pandoc version 1.12.1 and the Perl module [Pandoc::Elements](https://metacpan.org/pod/Pandoc%3A%3AElements).

The reverse action is possible with method `to_pandoc` of [Pandoc::Document](https://metacpan.org/pod/Pandoc%3A%3ADocument).
Additional shortcut methods such as `to_html` are available:

    $html = pandoc->parse( 'markdown' => '# A *section*' )->to_html;

Method `convert` should be preferred for simple conversions unless you want to
modify or inspect the parsed document in between.

## file( \[ $filename \[, @arguments \] \] )

Parse from a file (or STDIN) to a [Pandoc::Document](https://metacpan.org/pod/Pandoc%3A%3ADocument) object. Additional pandoc
options can be passed, for instance use HTML input format (`@arguments = qw(-f
html)`) instead of default markdown. This method requires at least pandoc
version 1.12.1 and the Perl module [Pandoc::Elements](https://metacpan.org/pod/Pandoc%3A%3AElements).

## require( $version\_requirement )

Return the Pandoc instance if its version number fulfills a given version
requirement. Throw an error otherwise.  Can also be called as constructor:
`Pandoc->require(...)` is equivalent to `pandoc->require` but
throws a more meaningful error message if no pandoc executable was found.

## version( \[ $version\_requirement \] )

Return the pandoc version as [Pandoc::Version](https://metacpan.org/pod/Pandoc%3A%3AVersion) object.  If a version
requirement is given, the method returns undef if the pandoc version does not
fulfill this requirement.  To check whether pandoc is available with a given
minimal version use one of:

    Pandoc->require( $minimum_version)                # true or die
    pandoc and pandoc->version( $minimum_version )    # true or false

## bin( \[ $executable \] )

Return or set the pandoc executable. Setting an new executable also updates
version and data\_dir by calling `pandoc --version`.

## symlink( \[ $name \] \[ verbose => 0|1 \] )

Create a symlink with given name to the executable and change executable to the
symlink location afterwards. An existing symlink is replaced. If `$name` is an
existing directory, the symlink will be named `pandoc` in there. This makes
most sense if the directory is listed in environment variable `$PATH`. If the
name is omitted or an empty string, symlink is created in subdirectory `bin`
of pandoc data directory.

## arguments( \[ @arguments | \\@arguments )

Return or set a list of default arguments.

## data\_dir( \[ @subdirs \] \[ $file \] )

Return the stated default data directory, introduced with Pandoc 1.11.  Use
function `pandoc_data_dir` alternatively to get the expected directory without
calling Pandoc executable.

## input\_formats

Return a list of supported input formats.

## output\_formats

Return a list of supported output formats.

## highlight\_languages

Return a list of programming languages which syntax highlighting is supported
for (via Haskell library highlighting-kate).

## extensions( \[ $format \] )

Return a hash of extensions mapped to whether they are enabled by default.
This method is only available since Pandoc 1.18 and the optional format
argument since Pandoc 2.0.6.

## libs

Return a hash mapping the names of Haskell libraries compiled into the
pandoc executable to [Pandoc::Version](https://metacpan.org/pod/Pandoc%3A%3AVersion) objects.

# SEE ALSO

This package includes [Pandoc::Version](https://metacpan.org/pod/Pandoc%3A%3AVersion) to compare Pandoc version numbers,
[Pandoc::Release](https://metacpan.org/pod/Pandoc%3A%3ARelease) to get Pandoc releases from GitHub, and
[App::Prove::Plugin::andoc](https://metacpan.org/pod/App%3A%3AProve%3A%3APlugin%3A%3Aandoc) to run tests with selected Pandoc executables.

See [Pandoc::Elements](https://metacpan.org/pod/Pandoc%3A%3AElements) for a Perl interface to the abstract syntax tree of
Pandoc documents for more elaborate document processing.

See [Pod::Pandoc](https://metacpan.org/pod/Pod%3A%3APandoc) to parse Plain Old Documentation format ([perlpod](https://metacpan.org/pod/perlpod)) for
processing with Pandoc.

See [Pandoc wrappers and interfaces](https://github.com/jgm/pandoc/wiki/Pandoc-wrappers-and-interfaces)
in the Pandoc GitHub Wiki for a list of wrappers in other programming
languages.

Other Pandoc related but outdated modules at CPAN include
[Orze::Sources::Pandoc](https://metacpan.org/pod/Orze%3A%3ASources%3A%3APandoc) and [App::PDoc](https://metacpan.org/pod/App%3A%3APDoc).

# AUTHOR

Jakob Voß

# CONTRIBUTORS

Benct Philip Jonsson

Dave Cross

# LICENSE

European Union Public Licence v. 1.2 (EUPL-1.2)

# NAME

Pandoc - interface to the Pandoc document converter

# STATUS

[![Build Status](https://travis-ci.org/nichtich/Pandoc-Wrapper.svg)](https://travis-ci.org/nichtich/Pandoc-Wrapper)
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

    # utility method to convert from string
    $latex = pandoc->convert( 'markdown' => 'latex', '*hello*' );

    # check executable
    pandoc or die "pandoc executable not found";

    # check minimum version
    pandoc->version(1.12) or die "pandoc >= 1.12 required";

    # access properties
    say pandoc->bin." ".pandoc->version;
    say "Default user data directory: ".pandoc->data_dir;

    # create an instance with default options
    my $md2latex = Pandoc->new(qw(-f markdown -t latex --smart));
    $md2latex->run({ in => \$markdown, out => \$latex });

# DESCRIPTION

This module provides a Perl interface to John MacFarlane's
[Pandoc](http://pandoc.org) document converter. The module exports utility
function `pandoc` but it can also be used as class.

# FUNCTIONS

## pandoc \[ @arguments \[, \\%options \] \]

## pandoc \[ \\@arguments \[, %options | \\%options \] \]

If called without arguments and options, the function returns a singleton
instance of class Pandoc to execute [methods](#methods), or `undef` if no
pandoc executable was found. Otherwise runs the pandoc executable with given
command line arguments. Additional options control input, output, and error
stream as described below.

Arguments and options can be passed as plain array/hash or as (possibly empty)
reference but one of them must be a reference if both are provided or if one of
both is empty.

    pandoc @arguments, { ... };    # ok
    pandoc [ ... ], %options;      # ok

    pandoc @arguments, %options;   # not ok!

If called with arguments and/or options, the function returns `0` on success.
Otherwise it returns the the exit code of pandoc executable or `-1` if
execution failed.

### Options

- in / out / err

    These options correspond to arguments `$stdin`, `$stdout`, and
    `$stderr` of [IPC::Run3](https://metacpan.org/pod/IPC::Run3), see there for details.

- binmode\_stdin / binmode\_stdout / binmode\_stderr

    These options correspond to the like-named options to [IPC::Run3](https://metacpan.org/pod/IPC::Run3), see
    there for details.

- binmode

    If defined any binmode\_stdin/binmode\_stdout/binmode\_stderr option which
    is undefined will be set to this value.

- return\_if\_system\_error

    Set to true by default to return the exit code of pandoc executable. 

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

# METHODS

## new( \[ \[ $executable \] \[, @arguments \] )

Create a new instance of class Pandoc or throw an exception if no pandoc
executable was found. The first argument, if given and not starting with `-`,
can be used to set the pandoc executable (`pandoc` by default). Additional
arguments are passed to the executable on each run.

Repeated use of this constructor with same arguments is not recommended because
`pandoc --version` is called for every new instance.

## run( \[ @arguments, \\%options \] )

## run( \[ \\@arguments \[ %options | \\%options \] \] )

Execute the pandoc executable (see function `pandoc` above).

## require( $minimum\_version )

Return the Pandoc instance if its version number is at least as high as the
given minimum version. Throw an error otherwise.  This method can also be
called as constructor: `Pandoc->require(...)` is equivalent to `pandoc->require` but throws a more meaningful error message if no pandoc
executable was found.

## convert( $from => $to, $input \[, @arguments \] )

Convert a string in format `$from` to format `$to`. Additional pandoc options
such as `--smart` and `--standalone` can be passed. The result is returned
in same utf8 mode (`utf8::is_unicode`) as the input.

## version( \[ $minimum\_version \] )

Return the pandoc version as [version](https://metacpan.org/pod/version) object. Returns undef if the version is
lower than a given minimum version.

## bin

Return the pandoc executable.

## arguments

Return a list of default arguments.

## data\_dir

Return the default data directory (only available since Pandoc 1.11).

## input\_formats

Return a list of supported input formats.

## output\_formats

Return a list of supported output formats.

# SEE ALSO

Use [Pandoc::Elements](https://metacpan.org/pod/Pandoc::Elements) for more elaborate document processing based on Pandoc.
Other Pandoc related but outdated modules at CPAN include
[Orze::Sources::Pandoc](https://metacpan.org/pod/Orze::Sources::Pandoc) and [App::PDoc](https://metacpan.org/pod/App::PDoc).

# AUTHOR

Jakob Voß

# CONTRIBUTORS

Benct Philip Jonsson

# LICENSE

GNU General Public License, Version 2

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 131:

    &#x3d;back without =over

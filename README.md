# NAME

Pandoc - interface to the Pandoc document converter

# STATUS

[![Build Status](https://travis-ci.org/nichtich/Pandoc-Wrapper.svg)](https://travis-ci.org/nichtich/Pandoc-Wrapper)
[![Coverage Status](https://coveralls.io/repos/nichtich/Pandoc-Wrapper/badge.svg)](https://coveralls.io/r/nichtich/Pandoc-Wrapper)
[![Kwalitee Score](http://cpants.cpanauthors.org/dist/Pandoc.png)](http://cpants.cpanauthors.org/dist/Pandoc)

# SYNOPSIS

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

# DESCRIPTION

This module provides a Perl interface to John MacFarlane's
[Pandoc](http://pandoc.org) document converter. The module exports utility
function `pandoc` but it can also be used as class.

# FUNCTIONS

## pandoc \[ @arguments \[, \\%options \] \]

## pandoc \[ \\@arguments \[, %options \] \]

## pandoc \[ \\@arguments \[, \\%options \] \]

Runs the pandoc executable with given command line arguments and options
and input/output/error redirected, as specified with the in/out/err
[options](#options).

Either of `@arguments` and `%options`, or both, may be passed as an
array or hash reference respectively. The items of the argument list to
`pandoc()` is interpreted according to these rules:

- If the first item is an array ref and the last is a hash ref

    these are `\@arguments` and `\%options` respectively and no other
    items are allowed.

- If the first item is an array ref and the last is _not_ a hash ref

    the first item is `\@arguments` and the remaining items if any
    (of which there must be an even number) are `%options`.

    This is useful in the common case where the command line arguments are
    the same over multiple calls, while the in/out/err [options](#options)
    are different for each call.

- If the first item is _not_ an array ref and the last is a hash ref

    the last item is `\%options` and the preceding items if any are
    `@arguments`.

- If _neither_ the first item is an array ref _nor_ the last is a hash ref

    All the items (if any) are `@arguments`.

Note that `\@arguments` must be the first item and `\%options` must be
the last, but either may be an empty array/hash reference.

If called without arguments and options, the function returns a singleton
instance of class Pandoc to access information about the executable version of
pandoc, or `undef` if no pandoc executable was found.  If called with
arguments and/or options, the function returns `0` on success.  Otherwise it
returns the the exit code of pandoc executable or `-1` if execution failed.

### Options

- in
- out
- err

    These options correspond to arguments `$stdin`, `$stdout`, and
    `$stderr` of [IPC::Run3](https://metacpan.org/pod/IPC::Run3), see there for details.

- binmode\_stdin
- binmode\_stdout
- binmode\_stderr

    These options correspond to the like-named options to [IPC::Run3](https://metacpan.org/pod/IPC::Run3), see
    there for details.

- binmode

    If defined any binmode\_stdin/binmode\_stdout/binmode\_stderr option which
    is undefined will be set to this value.

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

The `return_if_system_error` option of [IPC::Run3](https://metacpan.org/pod/IPC::Run3) is set to true by default;
the `pandoc` function returns the exit code from the pandoc executable.

# METHODS

## new

Create a new instance of class Pandoc or throw an exception if no pandoc
executable was found. Repeated use of this constructor is not recommended
unless you explicitly want to call `pandoc --version`, for instance because
the system environment has changed during runtime.

## run( \[ @arguments, \\%options \] )

## run( \[ \\@arguments, %options \] )

## run( \[ \\@arguments, \\%options \] )

Execute the pandoc executable (see function `pandoc` above).

## convert( $from => $to, $input \[, @arguments \] )

Convert a string in format `$from` to format `$to`. Additional pandoc options
such as `--smart` and `--standalone` can be passed. The result is returned 
in same utf8 mode (`utf8::is_unicode`) as the input.

## version( \[ $version \] )

Return the pandoc version if it is at least as new as a given version or if no
argument was provided.

## require( $version )

Throw an error if the pandoc version is lower than a given version.

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

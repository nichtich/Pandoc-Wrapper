# NAME

Pandoc - interface to the Pandoc document converter

# SYNOPSIS

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

# DESCRIPTION

This module provides a Perl interface to John MacFarlane's
[Pandoc](http://pandoc.org) document converter. The module exports function
`pandoc` by default.

# FUNCTIONS

## pandoc @arguments \[, \\%options \]

Executes the pandoc executable with given command line arguments and
input/output/error redirected as specified with the following options:

- in
- out
- err

The options correspond to arguments `$stdin`, `$stdout`, and `$stderr` of
[IPC::Run3](https://metacpan.org/pod/IPC::Run3), see there for details.

The function returns `0` on success. Otherwise it returns the the exit code of
pandoc or `-1` if execution failed.

If called without arguments and options, returns a singleton instance of class
Pandoc with information about the executable version of pandoc or `undef` if
no pandoc executable was found.

# METHODS

## new

Create a new instance of class Pandoc or throws an exception if no pandoc
executable was found. Using this constructor is not recommended unless you
explicitly want to call `pandoc --version`, for instance because a the system
environment has changed during runtime.

## run( @arguments, \\%options )

Execute the pandoc executable like function `pandoc`.

## version( $version )

Return the pandoc version if it is at least as new as a given version.

## require( $version )

Throw an error if the pandoc version is lower than a given version.

# SEE ALSO

Use [Pandoc:Elements](Pandoc:Elements) for more elaborate document processing based on Pandoc.
Other Pandoc related but outdated modules at CPAN include
[Orze::Sources::Pandoc](https://metacpan.org/pod/Orze::Sources::Pandoc) and [App::PDoc](https://metacpan.org/pod/App::PDoc).

# COPYRIGHT AND LICENSE

Copyright 2016- Jakob Voß

GNU General Public License, Version 2

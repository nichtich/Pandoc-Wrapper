use strict;
use Test::More;
use Test::Exception;
use File::Which;
use Pandoc;

plan skip_all => 'pandoc executable required' unless pandoc;

# import
{
    throws_ok { Pandoc->import('999.9.9') }
        qr/^pandoc 999\.9\.9 required, only found \d+(\.\d)+/,
        'import';
}

# require
{
    my $pandoc;
    lives_ok { $pandoc = Pandoc->require('0.1.0.1') } 'Pandoc->require';
    is_deeply $pandoc, pandoc, 'require returns singleton';
    lives_ok { pandoc->require('0.1.0.1') } 'pandoc->require';
    throws_ok { pandoc->require('x') } qr{ at t/methods.t}m, 'require throws)';
    throws_ok { pandoc->require('12345.67') }
        qr/^pandoc 12345\.67 required, only found \d+(\.\d)+/,
        'require throws';
}

# new
{
    my $pandoc = Pandoc->new; 
    is_deeply $pandoc, pandoc(), 'Pandoc->new';
    ok $pandoc != pandoc, 'Pandoc->new creates new instance';
    is $pandoc->bin, which('pandoc'), 'default executable';

    throws_ok { Pandoc->new('/dev/null/notexist') }
        qr{pandoc executable not found};
}

# version
{
    my $version = pandoc->version;
    like( $version, qr/^\d+(.\d+)+$/, 'pandoc->version' );
    isa_ok $version, 'version', 'pandoc->version is a version object';

    ok pandoc->version >= $version, 'compare same versions';
    is pandoc->version($version), $version, 'expect same version';

    ok pandoc->version > '0.1.2', 'compare lower versions';
    is pandoc->version('0.1.2'), $version, 'expect lower version';

    $version =~ s/(\d+)$/$1+1/e;
    ok pandoc->version < $version, 'compare higher versions';
    ok !pandoc->version($version), 'expect higher version';

    throws_ok { pandoc->version('abc') } qr{at t/methods\.t}m, 'invalid version';
}

# arguments
{
    my $pandoc = Pandoc->new(qw(--smart -t html));
    is_deeply [$pandoc->arguments], [qw(--smart -t html)], 'arguments';

    my ($in, $out) = ('*...*');
    is $pandoc->run([], in => \$in, out => \$out), 0, 'run';
    is $out, "<p><em>…</em></p>\n", 'use default arguments';

    is $pandoc->run( '-t' => 'latex', { in => \$in, out => \$out }), 0, 'run';
    is $out, "\\emph{\\ldots{}}\n", 'override default arguments';
}

# data_dir
{
    if (-d $ENV{HOME}.'/.pandoc' and pandoc->version('1.11')) {
        ok( pandoc->data_dir, 'pandoc->data_dir' );
    }
}

# input_formats / output_formats
{
    # ok pandoc->help, 'help';
	ok((grep { $_ eq 'markdown' } pandoc->input_formats), 'input_formats');
	ok((grep { $_ eq 'markdown' } pandoc->output_formats), 'output_formats');
}

done_testing;

use strict;
use Test::More;
use Test::Exception;
use Pandoc;

plan skip_all => 'pandoc executable required' unless pandoc;

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

    throws_ok { pandoc->version('abc') } qr{at t/pandoc\.t}m, 'invalid version';
}

my ($html, $md);
is pandoc({ in => \'*.*', out => \$html }), 0, 'pandoc({in =>..., out=>...}';
is $html, "<p><em>.</em></p>\n", 'markdown => html';

if (-d $ENV{HOME}.'/.pandoc') {
    ok( pandoc->data_dir, 'pandoc->data_dir' );
}

## no critic
pandoc -f => 'html', -t => 'markdown', { in => \$html, out => \$md };
is $md, "*.*\n", 'html => markdown';

is_deeply new Pandoc, pandoc(), 'Pandoc->new';

# require
{
    my $pandoc;
    lives_ok { $pandoc = Pandoc->require('0.1.0.1') } 'Pandoc->require';
    is_deeply $pandoc, pandoc, 'require returns singleton';
    lives_ok { pandoc->require('0.1.0.1') } 'pandoc->require';
    throws_ok { pandoc->require('x') } qr{ at t/pandoc.t}m, 'require throws)';
    throws_ok { pandoc->require('12345.67') }
        qr/^pandoc 12345\.67 required, only found \d+(\.\d)+/,
        'require throws';
}

throws_ok { Pandoc->import('999.9.9') }
    qr/^pandoc 999\.9\.9 required, only found \d+(\.\d)+/,
    'import';

done_testing;

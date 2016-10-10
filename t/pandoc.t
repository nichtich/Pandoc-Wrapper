use strict;
use Test::More;
use Test::Exception;
use Pandoc;

plan skip_all => 'pandoc executable required' unless pandoc;

like( pandoc->version, qr/^\d+(.\d+)+$/, 'pandoc->version' );
like( Pandoc->version, qr/^\d+(.\d+)+$/, 'Pandoc->version' );

if (-d $ENV{HOME}.'/.pandoc') {
    ok( pandoc->data_dir, 'pandoc->data_dir' );
    ok( Pandoc->data_dir, 'Pandoc->data_dir' );
}

like( pandoc->version('0.1.2'), qr/^\d+(.\d+)+$/, 'pandoc->version(...)' );

my ($html, $md);
is pandoc({ in => \'*.*', out => \$html }), 0, 'pandoc({in =>..., out=>...}';
is $html, "<p><em>.</em></p>\n", 'markdown => html';

## no critic
pandoc -f => 'html', -t => 'markdown', { in => \$html, out => \$md };
is $md, "*.*\n", 'html => markdown';

is_deeply new Pandoc, pandoc(), 'Pandoc->new';

lives_ok { pandoc->require('0.1.0.1') } 'pandoc->require';

lives_ok { Pandoc->require('0.1.0.1') } 'Pandoc->require';

throws_ok { pandoc->require('a') }
    qr/^invalid version number: a/,
    'require: throws';

throws_ok { pandoc->require('12345.67') }
    qr/^pandoc 12345\.67 required, only found \d+(\.\d)+/,
    'require: throws';

throws_ok { Pandoc->import('999.9.9') }
    qr/^pandoc 999\.9\.9 required, only found \d+(\.\d)+/,
    'import';

done_testing;

use strict;
use Test::More;
use Test::Exception;
use Pandoc qw(-t latex);

is_deeply [ pandoc->arguments ], [qw(-t latex)], 'import with arguments';

throws_ok { Pandoc->VERSION(99) } qr/^pandoc 99 required/, 'use Pandoc 99';
lives_ok { Pandoc->VERSION(pandoc->version) };

done_testing;

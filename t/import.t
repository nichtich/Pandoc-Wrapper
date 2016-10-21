use strict;
use Test::More;
use Pandoc qw(-t latex);

is_deeply [ pandoc->arguments ], [qw(-t latex)], 'import with arguments';

done_testing;

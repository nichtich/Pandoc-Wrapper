use strict;
use Test::More;
use Test::Exception;
use Pandoc;

plan skip_all => 'pandoc executable required' unless pandoc;

my $latex = pandoc->convert('html' => 'latex', '<em>hello</em>');
is $latex, '\emph{hello}', 'html => latex';

my $html = pandoc->convert('markdown' => 'html', '...', '--smart');
is $html, '<p>…</p>', 'markdown => html';
is $html, "<p>\xE2\x80\xA6</p>", 'convert returns bytes'; 

utf8::decode($html);
my $markdown = pandoc->convert('html' => 'markdown', $html);
is $markdown, "\x{2026}", 'convert returns Unicode to Unicode'; 

eval { pandoc->convert('latex' => 'html', '', '--template' => '') };
like $@, qr/^pandoc: /, 'croak on error';

like pandoc->convert('latex' => 'html', '$\rightarrow$'), qr/→/, 'unicode';

done_testing;

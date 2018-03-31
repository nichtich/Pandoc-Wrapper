use strict;
use Test::More;
use File::Temp;

plan skip_all => 'these tests are for release candidate testing'
    unless $ENV{RELEASE_TESTING};

require Pandoc::Release;

my @releases = Pandoc::Release->list( since => '2.1' );
like $releases[0]->{name}, qr/^pandoc/i, 'fetch releases';
note $_ for map { $_->{tag_name} } @releases;

@releases = Pandoc::Release->list( since => '9.0' );
is_deeply \@releases , [], 'no > 9.0 releases';

my @releases = Pandoc::Release->list( range => '<=2.0.1, >1.19.2' );
is_deeply [ map {$_->{tag_name}} @releases ],
    [qw(2.0.1 2.0.0.1 2.0 1.19.2.1)], 'range releases';

done_testing;

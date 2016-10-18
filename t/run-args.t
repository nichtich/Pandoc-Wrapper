use strict;
use Test::More 0.96; # for subtests
use Test::Exception;
use Pandoc;

plan skip_all => 'pandoc executable required' unless pandoc;
# XXX: does Test::More/IPC::Run3 lack write permissions?

my $args = ['-t' => 'markdown'];

subtest 'run(@args, \%opts)' => sub {
    my $in = 'foo';
    my %opts = ( in => \$in, out => \my($out), err => \my($err) );
    lives_ok { pandoc->run( @$args, \%opts ) }, 'run';
    like $out, qr!^\s*foo\s*$!, 'stdout';
    note $out;
    is $err //= "", "", 'stderr';
};

subtest '->run(\@args, \%opts)' => sub {
    my $in = 'foo';
    my %opts = ( in => \$in, out => \my($out), err => \my($err) );
    lives_ok { pandoc->run( $args, \%opts ) }, 'run';
    like $out, qr!^\s*foo\s*$!, 'stdout';
    is $err //= "", "", 'stderr';
};

subtest '->run(\@args, %opts)' => sub {
    my $in = 'foo';
    my %opts = ( in => \$in, out => \my($out), err => \my($err) );
    lives_ok { pandoc->run( $args, %opts ) }, 'run';
    like $out, qr!^\s*foo\s*$!, 'stdout';
    is $err //= "", "", 'stderr';
};

subtest '->run([], %opts)' => sub {
    my $in = 'foo';
    my %opts = ( in => \$in, out => \my($out), err => \my($err) );
    lives_ok { pandoc->run( [], %opts ) }, 'run';
    like $out, qr!<p>foo</p>!, 'stdout';
    is $err //= "", "", 'stderr';
};

subtest '->run(\@args, qw[odd length list])' => sub {
    my $in = 'foo';
    my %opts = ( in => \$in, out => \my($out), err => \my($err) );
    throws_ok { pandoc->run( $args, %opts, 'foo' ) } 
        qr!^\QToo many or ambiguous arguments!, 'run';
};

subtest '->run(\@args, ..., \%opts)' => sub {
    my $in = 'foo';
    my %opts = ( in => \$in, out => \my($out), err => \my($err) );
    throws_ok { pandoc->run( $args, qw[foo, bar], \%opts ) } 
        qr!^\QToo many or ambiguous arguments!, 'run';
};

done_testing;

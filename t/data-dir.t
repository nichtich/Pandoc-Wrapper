use strict;
use Test::More;
use File::Spec::Functions 'catdir';
use Pandoc;

is catdir($ENV{HOME} || $ENV{USERDIR}, '.pandoc'), pandoc_data_dir, 'pandoc_data_dir';

done_testing;

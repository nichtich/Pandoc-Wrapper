package Pandoc::Version;
use strict;
use warnings;
use 5.010;

use utf8;

=head1 NAME

Pandoc::Version - version number of pandoc and its libraries

=cut

use overload '""' => 'string', '0+' => 'number', 
    cmp => 'cmp', '<=>' => 'cmp', fallback => 1;
use Carp qw(croak);
use Scalar::Util qw(reftype blessed);

our @CARP_NOT = ('Pandoc');

sub new {
    my $class = shift;

    # We accept array or string input
    # (or mixed but let's not document that!)
    my @nums = 
        map {
            my $num = $_;
            $num =~ /^[0-9]+$/ or croak 'invalid version number';
            $num =~ s/^0+(?=\d)//; # ensure decimal interpretation
            $num = 0+ $num;
            $num 
        } 
        map { s/^v//i; split /\./ }
        map { 'ARRAY' CORE::eq (reftype $_ // "") ? @$_ : $_ }
        map { $_ // '' } @_;

    croak 'invalid version number' unless @nums;

    return bless \@nums => $class;
}

sub string { join '.', @{ $_[0] } }

sub number {
    my ($major, @minors) = @{ $_[0] };
    no warnings qw(uninitialized numeric);
    if ( @minors ) {
        my $minor = join '', map { sprintf '%03d', $_ } @minors;
        return 0+ "$major.$minor";    # return a true number
    }
    return 0+ $major;
}

sub cmp {
    my ($a, $b) = map {
        (blessed $_ and $_->isa('Pandoc::Version'))
            ? $_ : Pandoc::Version->new($_ // ())   
    } ($_[0], $_[1]);
    return $a->number <=> $b->number;
}

sub TO_JSON {
    my ($self) = @_;
    return [ map { 0+ $_ } @$self ];
}

1;

__END__

=head1 SYNOPSIS

  $version = Pandoc::Version->new("1.17.2");     # create version
  $version = bless [1,17,2], 'Pandoc::Version';  # equivalent

  "$version";       # stringify to "1.17.2"
  $version > 1.9;   # compare
  $version->[0];    # major

=head1 DESCRIPTION

This module is used to store and compare version numbers of pandoc executable
and Haskell libraries compiled into pandoc. A Pandoc::Version object is an
array reference of one or more non-negative integer values. In most cases there
is no need to create such version objects. Just use the instances returned by
methods C<version> and C<libs> of module L<Pandoc> and trust in in overloading.

=head1 METHODS

=head2 string

Return a string representation of a version, for instance C<"1.17.0.4">. This
method is automatically called by overloading in string context.

=head2 number

Return a number representation of a version, for instance C<1.017000004>. This
method is automatically called by overloading in number context.

=head2 cmp

Compare two version numbers. This is method is used automatically by
overloading to compare version objects with strings or numbers (operators
C<eq>, C<lt>, C<le>, C<ge>, C<==>, C<< < >>, C<< > >>, C<< <= >>, and C<< >=
>>).

=head2 TO_JSON

Return an array reference of the version number to serialize in JSON format.

=head1 SEE ALSO

L<version> is a similar module for Perl version numbers.

=cut
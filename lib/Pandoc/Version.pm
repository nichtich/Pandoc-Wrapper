package Pandoc::Version;
use strict;
use warnings;
use 5.010;

use utf8;

=head1 NAME

Pandoc::Version - Pandoc version number

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

=head1 DESCRIPTION

Instances of Pandoc::Version store version number of pandoc executable or other
libraries to be used with module L<Pandoc>. Each version number is a non-empty
array reference of non-negative integer values.

=head1 METHODS

=head2 string

Return a string representation of a version, for instance C<"1.17.0.4">. This
method is automatically called in string context.

=head2 number

Return a number representation of a version, for instance C<1.017000004>. This
method is automatically called in number context.

=head2 cmp

Compare two version numbers. This is method is used to compare version objects
with operators C<eq>, C<lt>, C<le>, C<ge>, C<==>, C<< < >>, C<< > >>, 
C<< <= >>, and C<< >= >>.

=head2 TO_JSON

Return an array reference of the version number.

=head1 SEE ALSO

See module L<version>.

=cut

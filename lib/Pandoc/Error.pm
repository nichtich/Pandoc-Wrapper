package Pandoc::Error;
use strict;
use warnings;
use 5.010;

our $VERSION = '0.8.4';

use overload '""' => 'message', fallback => 1;
use Carp;

$Carp::CarpInternal{ (__PACKAGE__) }++;   # don't include package in stack trace

sub new {
    my ( $class, %fields ) = @_ % 2 ? @_ : ( shift, message => @_ );
    $fields{message} = Carp::shortmess( $fields{message} // $class );
    bless \%fields, $class;
}

sub throw {
    die ref $_[0] ? $_[0] : shift->new(@_);
}

sub message {
    $_[0]->{message};
}

1;

=head1 NAME

Pandoc::Error - Pandoc document processing error

=head1 SYNOPSIS

  use Try::Tiny;

  try {
      ...
  } catch {
      if ( blessed $_ && $_->isa('Pandoc::Error') ) {
          ...
      }
  };

=head1 METHODS

=head2 throw( [ %fields ] )

Throw an existing error or create and throw a new error. Setting field
C<message> is recommended. The message is enriched with error location.  A
stack trace can be added with L<$Carp::Verbose|Carp/$Carp::Verbose> or
L<Carp::Always>.

=head2 message

The error message. Also returned on stringification.

=head1 SEE ALSO

This class does not inherit from L<Throwable>, L<Exception::Class> or
L<Class::Exception> but may do so in a future version.

=head1 AUTHOR

Jakob Voß

=head1 LICENSE

    This software distribution is subject to the EUPL, Version 1.2 or subsequent
    versions of the EUPL (the "Licence"); you may not use this file except in
    compliance with the License. You may obtain a copy of the License at
    <http://joinup.ec.europa.eu/software/page/eupl>

    Software distributed under the License is distributed on an "AS IS" basis,
    WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
    the specific language governing rights and limitations under the License.

=cut

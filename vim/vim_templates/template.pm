package <MODULE NAME>;

# ABSTRACT: 
#
use MM::Moose;

use MM::Types qw( ArrayRef Bool Str );

=head1 SYNOPSIS

   my $example = <MODULE NAME>->new(
      request_tag => 'B68EEB15-ED8C-4431-B1B1-401C78D49CAB',
   );

=cut


has evil => (
    is            => 'ro',
    isa           => Bool,
    default       => 0,
    documentation => 'Evil switch.  Please leave turned off.',
);


with (
    'MM::Role::HasConfig',
);

=head1 DESCRIPTION

This is an example module that shows several things:

=for :list
* How we use custom pod weaver syntax, for example this list
* How to document methods
* How to document attributes

Note that none of the methods (or other parts of the code) are actually
implemented.

=cut

# Module implementation here
    #

=method <MODULE NAME>->run( $config )

Constructs a new instance from a config object and returns it.

Note: this is an example of how to document a class method, where by we use the
class name in the C<=method ...> pod declaration.  It also show how we should
document the return type, and how we've omitted the arguments to show there are
none.

=cut

sub run ( $class, $config ) {
    ...;
}


=head1 SEE ALSO

=for :list
* L<MM::Example::Role> is an example role
* L<MM::Example::Exporter> is an example exporter

=cut

__PACKAGE__->meta->make_immutable;
1;

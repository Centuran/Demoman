package VM::Spawn::DNS;
use Moo::Role;

=pod

=head1 VM::Spawn::DNS

An object implementing this abstract role is responsible for adding
and removing DNS entries for your VMs.

=head2 C<method create($hostname, $ip_address) { ... }>

Add a DNS entry for C<$hostname> pointing to C<$ip_address>.

=head2 C<method delete($hostname, $ip_address) { ... }>

Remove a DNS entry for C<$hostname> pointing to C<$ip_address>.

=cut

sub create { ... }
sub delete { ... }

'vodka';

package VM::Spawn::Provider;
use Moo::Role;

=pod

=head1 VM::Spawn::Provider

An object implementing this abstract role is responsible for spawning
and deleting VMs. You'll typically have an object implementing this
for different providers (DigitalOcean, Amazon, OVH etc.).

=head2 C<method create($name, $type) { ... }>

Create a new VM, identified as C<$name> (typically the hostname).
C<$type> describes the target application for the new VM; a C<Provider>
may use this information to use a specialized VM image on creation:
the details to how exactly C<$type> is treated are up to a specific
C<Provider> implementation.

C<create()> returns two objects: the IP address of the new machine
(scalar string) and the hashref of custom, provider-specific data
(for example droplet id for DigitalOcean). They should then stored
accordingly in a C<VM::Spawn::Machine> object (as C<ip_address> and
C<data> respectively) so they can be later correctly recognized by
the C<delete()> method.

=head2 C<method delete($vm) { ... }>

Deletes the VM described in the C<$vm> argument, which should be an
instance of C<VM::Spawn::Machine>. Does not return any value.

=cut

sub create { ... }
sub delete { ... }

'cola';

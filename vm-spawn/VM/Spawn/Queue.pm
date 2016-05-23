package VM::Spawn::Queue;
use Moo::Role;

=pod

=head1 VM::Spawn::Queue

An object implementing this abstract role is responsible for providing
us means to access the currently requested and currently active VMs.

=head2 C<method for_expired($callback) { ... }>

This will set off C<$callback> for each VM in the queue that's
Time To Live is over. An instance of C<VM::Spawn::Machine> will be
passed to C<$callback>

Currently, no return value is expected -- C<VM::Spawn::Queue> assumes
success and will remove the machine from the queue. This is likely to
change in the future.

=head2 C<method for_requested($callback) { ... }>

This will set off C<$callback> for each VM request in the queue
An instance of C<VM::Spawn::Request> will be passed to C<$callback>.

C<$callback> should return an instance of VM::Spawn::Machine on
successful creation. If a false value is returned instead, the request
will remain in the queue to be retried later. If all went well, the
newly created machine will be removed from the request queue and will
be marked to expire in a (configurable) future. It's up to a specific
C<VM::Spawn::Queue> implementation to decide when that future happens.

=head2 C<method cancel_request($id) { ... }>

This will cancel the request for request C<$id>, typically if we decide
to ignore a certain request if, say, that user exceeded their VM quota.
The C<$id> is the same value as in C<VM::Spawn::Request::id> field.

=head2 C<method get_active_count() { ... }>

=head2 C<method get_active_count_for_ip($ip) { ... }>

Both of these methods return a number of currently active VMs, with
the second one, as the name suggests, filtering them by an IP address.
Typically used to not exceed a certain total VM count (for a user,
or globally).

=cut

sub for_expired             { ... }
sub for_requested           { ... }
sub cancel_request          { ... }
sub get_active_count        { ... }
sub get_active_count_for_ip { ... }

'steak';

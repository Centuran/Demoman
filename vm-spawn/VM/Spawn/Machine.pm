package VM::Spawn::Machine;
use Moo;

has 'hostname'   => (is => 'ro', required => 1);
has 'ip_address' => (is => 'ro', required => 1);
has 'symbol'     => (is => 'ro', required => 1);
# any data structure with additional details (droplet ID etc.)
has 'data'       => (is => 'ro');

'beer';

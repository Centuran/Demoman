package VM::Spawn::Request;
use Moo;

has 'id'          => (is => 'ro', required => 1);
has 'ip_address'  => (is => 'ro', required => 1);
has 'email'       => (is => 'ro', required => 1);
has 'timestamp'   => (is => 'ro', required => 1);
has 'language'    => (is => 'ro');
has 'application' => (is => 'ro');

'wine';

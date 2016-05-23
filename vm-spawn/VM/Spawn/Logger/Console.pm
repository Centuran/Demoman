package VM::Spawn::Logger::Console;
use Moo;
with 'VM::Spawn::Logger';

sub log {
    my ($self, $text) = @_;
    print STDERR "$text\n"; 
}

'cider';

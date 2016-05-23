package VM::Spawn::Logger;
use Moo::Role;

sub log { ... }

sub log_expired {
    my ($self, $vm) = @_;
    $self->log("[EXPIRED] " . $vm->hostname);
}

sub log_requested {
    my ($self, $req) = @_;
    $self->log(sprintf("[REQUESTED] %s for %s",
                       $req->application, $req->email));

}

'cider';

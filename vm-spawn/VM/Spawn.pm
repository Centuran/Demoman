package VM::Spawn;
use Moo;

use VM::Spawn::Request;
use VM::Spawn::Machine;

# components
has 'queue'          => (is => 'ro', required => 1);
has 'provider'       => (is => 'ro', required => 1);
has 'dns'            => (is => 'ro', required => 1);
has 'apphandler_for' => (is => 'ro', required => 1);
has 'logger'         => (is => 'ro', required => 1);
has 'notifier_for'   => (is => 'ro', required => 1);

# configuration
has 'max_vms'                => (is => 'ro', required => 1);
has 'max_vms_per_ip_address' => (is => 'ro', required => 1);
has 'vms_domain'             => (is => 'ro', required => 1);
has 'min_req_interval'       => (is => 'ro', required => 1);
has 'dry_run'                => (is => 'rw', default => sub { 0 });

sub process_expired {
    my $self = shift;

    $self->queue->for_expired(sub {
        my $vm = shift;

        $self->logger->log_expired($vm);
        return if $self->dry_run;

        $self->provider->delete($vm);
        $self->dns->delete($vm->hostname, $vm->ip_address);
        return "I'm making a note here: HUGE SUCCESS";
    });
}

sub process_requested {
    my $self = shift;

    my $active_vms = $self->queue->get_active_count();
    my %last_request_for;
    my @fresh_vms;

    sub create_symbol {
        my $id = shift;
        my $symbol_lo = 111;
        my $symbol_hi = 999;

        $symbol_lo + ($id - 1) % ($symbol_hi - $symbol_lo + 1);
    }

    $self->queue->for_requested(sub {
        my $req = shift;

        if ($self->max_vms && ($active_vms >= $self->max_vms)) {
            $self->logger->log('Reached maximum number of active VMs');
            return;
        }

        my $active_vms_for_ip = $self->queue->get_active_count_for_ip(
            $req->ip_address
        );
        if ($self->max_vms_per_ip_address &&
            ($active_vms_for_ip >= $self->max_vms_per_ip_address))
        {
            self->logger->log('Reached maximum number of active VMs "
                . "for this IP address (' .  $req->ip_address . ")");
            return;
        }

        my $request_key = $req->ip_address . $req->email;
        if ($last_request_for{$request_key}) {
            my $interval = $req->timestamp->subtract_datetime_absolute(
                $last_request_for{$request_key});
            if ($interval->seconds < $self->min_req_interval) {
                $self->logger->log("Too many requests from "
                           . $req->ip_address . " for "
                           . $req->email . ", cancelling");
                $self->queue->cancel_request($req->id)
                    unless $self->dry_run;
                return;
            }
        }
        $last_request_for{$request_key} = $req->timestamp;

        $self->logger->log_requested($req);
        return if $self->dry_run;

        my $symbol = create_symbol($req->id);
        my $hostname = "$symbol." . $self->vms_domain;

        my $type = $req->application;

        my ($ip, $vmdata) = $self->provider->create($hostname, $type);
        $self->dns->create($hostname, $ip);

        $active_vms++;

        push @fresh_vms, {
            hostname      => $hostname,
            ip_address    => $ip,
            email_address => $req->email,
            email_lang    => $req->language,
            type          => $type,
        };

        return VM::Spawn::Machine->new(
            symbol     => $symbol,
            hostname   => $hostname,
            ip_address => $ip,
            data       => $vmdata,
        );
    });

    for my $vm (@fresh_vms) {
        my $passwd_suffix = sprintf("%04d", int(rand(10000)));
        $vm->{passwd_suffix} = $passwd_suffix;

        my $type = $vm->{type} . "-" . $vm->{email_lang};

        my $ah = $self->apphandler_for->($type);

        $ah->setup($vm);

        $self->notifier_for->($type)->notify(
            $vm->{email_address},
            {
                hostname      => $vm->{hostname},
                passwd_suffix => $vm->{passwd_suffix},
            }
        );
    }
}

'brandy';

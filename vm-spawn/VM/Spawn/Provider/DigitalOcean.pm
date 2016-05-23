package VM::Spawn::Provider::DigitalOcean;
use Moo;
with 'VM::Spawn::Provider';

use WebService::DigitalOcean;

=pod

=head1 VM::Spawn::Provider::DigitalOcean

This implements the VM::Spawn::Provider role for managing the VMs
using DigitalOcean.

=head2 Required attributes

=head3 C<token>

Your DigitalOcean API access token.

=head3 C<images>

A hashref mapping types of VMs (the C<$type> argument to C<create()>
to numerical IDs of DigitalOcean images.

=head3 C<ssh_keys>

An arrayref with a list of ssh keys to be copied to a newly created VM.
These can be either fingerprints (like 'fe:ed:de:ad:be:ef:ca:fe') or
DigitalOcean key IDs (like 12345).

=head2 Optional attributes

=head3 C<region>

A string describing the region in which to set up VMs.
Defaults to "ams2".

=head3 C<region>

A string describing the region in which to set up VMs.
Defaults to "ams2".

=head3 C<size>

A string describing the amount of memory the target VM is to have.
Defaults to "2gb".

=cut

has 'token'    => (is => 'ro', required => 1);
has 'images'   => (is => 'ro', required => 1);
has 'ssh_keys' => (is => 'rw', required => 1);

has 'region'   => (is => 'rw', default => sub { "ams2" });
has 'size'     => (is => 'rw', default => sub { "2gb" });

has 'docean'   => (is => 'ro');

sub BUILD {
    my $self = shift;
    $self->{docean} = WebService::DigitalOcean->new({
        token => $self->token
    });
}

sub create {
    my ($self, $hostname, $type) = @_;

    my $image = $self->images->{$type};

    my $response = $self->docean->droplet_create({
        name     => $hostname,
        region   => $self->region,
        size     => $self->size,
        image    => $image,
        ssh_keys => $self->ssh_keys,
    });

    my $droplet_id = $response->{content}{id};

    do {
        sleep(10);
        $response = $self->docean->droplet_get($droplet_id);
    } while (!defined $response->{content}{networks}{v4}[0]{ip_address});

    my $ip_address = $response->{content}{networks}{v4}[0]{ip_address};

    return ($ip_address, { digital_ocean => {droplet_id=>$droplet_id} })
}

sub delete {
    my ($self, $vm) = @_;
    my $droplet_id = $vm->data->{digital_ocean}{droplet_id};
    deletion_attempt:
    while (1) {
        my $result = $self->docean->droplet_delete($droplet_id);

        if ($result->{is_success}) {
            last deletion_attempt;
        }
        else {
            # In case we're trying to destroy a droplet
            # that no longer exists
            last deletion_attempt if $result->{status_line} =~ /^404 /;
            sleep(10);
        }
    }
}


'whiskey';

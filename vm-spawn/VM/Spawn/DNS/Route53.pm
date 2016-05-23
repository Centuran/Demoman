package VM::Spawn::DNS::Route53;
use Moo;
with 'VM::Spawn::DNS';

use WebService::Amazon::Route53;

=head1 VM::Spawn::DNS::Route53

This implements the C<VM::Spawn::DNS> abstract role for Amazon's Route53
DNS service.

=head2 Required attritbutes

=head3 C<id>, C<key>

Your Route53 API access credentials.

=head3 C<zone>

Your DNS zone, like 'example.com.'

=cut

has 'id'   => (is => 'ro', required => 1);
has 'key'  => (is => 'ro', required => 1);
has 'zone' => (is => 'ro', required => 1);

has 'r53'     => (is => 'ro');
has 'zone_id' => (is => 'ro');

sub BUILD {
    my $self = shift;

    $self->{r53} = WebService::Amazon::Route53->new(
        id  => $self->id,
        key => $self->key,
    );

    my $response = $self->r53->find_hosted_zone(name => $self->zone);
    (my $zone_id = $response->{hosted_zone}{id}) =~ s{^/hostedzone/}{};
    $self->{zone_id} = $zone_id;
}

sub create {
    my ($self, $hostname, $ip_address) = @_;
    $self->change('create', $hostname, $ip_address);
}

sub delete {
    my ($self, $hostname, $ip_address) = @_;
    $self->change('delete', $hostname, $ip_address);
}

sub change {
    my ($self, $action, $hostname, $ip_address) = @_;

    my $change_info = $self->r53->change_resource_record_sets(
        zone_id => $self->zone_id,
        action  => $action,
        name    => "$hostname.",
        type    => 'A',
        ttl     => 300,
        value   => $ip_address
    );
}

'tea';

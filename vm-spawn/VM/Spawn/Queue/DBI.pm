package VM::Spawn::Queue::DBI;
use Moo;
with 'VM::Spawn::Queue';

use DBI;
use DateTime::Format::MySQL;
use JSON;

=pod

=head1 VM::Spawn::Queue::DBI

This implements the VM::Spawn::Queue role, fetching the request from
a database and storing the created VMs there too. The schema looks
somewhat like this (see the complete schema in a separate file included
with this module):

    CREATE TABLE `vms` (
        `id`                  int(11) NOT NULL AUTO_INCREMENT,
        `created_on`          datetime DEFAULT NULL,
        `expires_on`          datetime DEFAULT NULL,
        `destroyed_on`        datetime DEFAULT NULL,
        /* ... more fields ... */
        PRIMARY KEY (`id`)
    )

A row is considered to be a request if C<created_on> is C<NULL>.
It's considered to be expired if C<expires_on> is in the past and
C<destroyed_on> is C<NULL>. C<expires_on> is set on VM creation
according to the C<vm_lifetime> attribute, documented below.

=cut

has 'driver'   => ( is => 'ro', required => 1 );
has 'database' => ( is => 'ro', required => 1 );
has 'host'     => ( is => 'ro', required => 1 );
has 'port'     => ( is => 'ro', required => 1 );
has 'username' => ( is => 'ro', required => 1 );
has 'password' => ( is => 'ro', required => 1 );

=pod

=head2 Attributes

=head3 C<driver>, C<database>, C<host>, C<port>, C<username>, C<password>

These attributes (B<required>), are all used to create a connection to
the database using DBI.

=head3 C<vm_lifetime>

This attribute represents the minimal time (in hours) that the
VM needs to live to be considered expired. Defaults to 48 hours.

=cut

has 'vm_lifetime' => (is => 'rw', default => sub { 48 });

has 'dbh' => ( is => 'ro' );

sub BUILD {
    my $self = shift;

    $self->{dbh} = DBI->connect(
        'DBI:' . $self->driver . ':' .
            'database=' . $self->database . ';' . 
            'host=' . $self->host,
        $self->username,
        $self->password,
    );
}

sub for_expired {
    my ($self, $cb) = @_;

    my $now = DateTime->now;

    my $sth = $self->dbh->prepare(
        'SELECT * FROM vms WHERE expires_on < ? AND '
        .  'destroyed_on IS NULL');
    $sth->execute($now->ymd . ' ' . $now->hms);
    
    while (my $row = $sth->fetchrow_hashref) {
        my $vm = VM::Spawn::Machine->new(
            hostname   => $row->{hostname},
            ip_address => $row->{ip_address},
            symbol     => $row->{symbol},
            data       => decode_json($row->{data}),
        );

        $cb->($vm); # the actual deletion, hopefully

        $now = DateTime->now;

        $self->dbh->do(
            'UPDATE vms SET destroyed_on = ? WHERE id = ?',
            undef,
            $now->ymd . ' ' . $now->hms,
            $row->{id}
        );
    }
}

sub for_requested {
    my ($self, $cb) = @_;
    my $sth = $self->dbh->prepare(
        'SELECT * FROM vms WHERE created_on IS NULL');
    $sth->execute;

    while (my $row = $sth->fetchrow_hashref) {
        my $req = VM::Spawn::Request->new(
            id          => $row->{id},
            ip_address  => $row->{request_ip_address},
            email       => $row->{request_email},
            language    => $row->{request_language},
            timestamp   => DateTime::Format::MySQL->parse_datetime(
                               $row->{requested_on}
                           ),
            application => $row->{request_application},
        );
        my $vm = $cb->($req); # the actual creation
        next unless $vm;

        my $created_dt = DateTime->now;
        my $expires_dt = $created_dt->clone->add(
            hours => $self->vm_lifetime);

        $self->dbh->do(
            'UPDATE vms SET created_on = ?, expires_on = ?, ' .
            'symbol = ?,  hostname = ?, ip_address = ?, ' .
            'data = ? WHERE id = ?',
            undef,
            $created_dt->ymd . ' ' . $created_dt->hms,
            $expires_dt->ymd . ' ' . $expires_dt->hms,
            $vm->symbol,
            $vm->hostname,
            $vm->ip_address,
            encode_json($vm->data),
            $req->id,
        );
    }
}

sub cancel_request {
    my ($self, $id) = @_;
    # perhaps it's better to keep it in the DB, but mark it somehow
    # as cancelled? I didn't feel like cheating with setting *_on to 0
    my $sth = $self->dbh->prepare('DELETE FROM vms WHERE id = ?');
    $sth->execute($id);
}

sub get_active_count {
    my ($self) = @_;
    my $sth = $self->dbh->prepare('SELECT COUNT(*) active_vms FROM vms '
            .  'WHERE created_on IS NOT NULL AND destroyed_on IS NULL;');
    $sth->execute;
    return $sth->fetchrow_hashref->{active_vms};
}

sub get_active_count_for_ip {
    my ($self, $ip) = @_;
    my $sth = $self->dbh->prepare(
        'SELECT COUNT(*) active_vms_for_ip ' .
        'FROM vms WHERE request_ip_address = ? ' .
        'AND created_on IS NOT NULL ' .
        'AND destroyed_on IS NULL');
    $sth->execute($ip);
    return $sth->fetchrow_hashref->{active_vms_for_ip};
}

'bacon';

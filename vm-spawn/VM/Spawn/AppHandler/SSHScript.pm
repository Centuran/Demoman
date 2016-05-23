package VM::Spawn::AppHandler::SSHScript;
use Moo;
with 'VM::Spawn::AppHandler';

use File::Basename;
use Carp::Always;
use Net::OpenSSH;

has 'setup_script_path' => (is => 'ro', required => 1);
has 'ssh_key_path'      => (is => 'ro', required => 1);

sub ssh_retry ($$&) {
    my ($ssh, $retries, $code) = @_;

    do {
        print STDERR "Retries left: $retries\n";
        $code->();

        sleep(10) if $$ssh->error;
    } while ($retries-- && $$ssh->error);
}

sub setup {
    my ($self, $ip_address, $opts) = @_;
    my $ssh;
    ssh_retry \$ssh, 20, sub {
        $ssh = Net::OpenSSH->new(
            'root@' . $ip_address,
            key_path    => $self->ssh_key_path,
            timeout     => 30,
            master_opts => [ -o => "StrictHostKeyChecking=no" ],
        );
    };

    ssh_retry \$ssh, 3, sub {
        $ssh->scp_put($self->setup_script_path, '/tmp');
    };

    $ssh->error and
        die "scp failed: " . $ssh->error;

    my $scriptname = basename $self->setup_script_path;

    my $email = $opts->{email_address};
    ssh_retry \$ssh, 3, sub {
        my ($out, $err) = $ssh->capture2('perl', "/tmp/$scriptname",
            $ssh->shell_quote($email), $opts->{passwd_suffix},
            $opts->{hostname});
    };

    $ssh->error and die "remote command failed: " . $ssh->error;

    $self->notifier->notify(
        $opts->{email_address}, $opts->{email_lang}, {
            hostname      => $opts->{hostname},
            passwd_suffix => $opts->{passwd_suffix},
        }
    );
}

'coffee';

use 5.020;
use YAML::XS;
use VM::Spawn::Queue::DBI;
use VM::Spawn::Provider::DigitalOcean;
use VM::Spawn::DNS::Route53;
use VM::Spawn::AppHandler::SSHScript;
use VM::Spawn::Notifier::Email;
use VM::Spawn::Logger::Console;
use VM::Spawn::Request;
use VM::Spawn::Machine;
use VM::Spawn;
use File::Slurp;

my $config = Load(scalar read_file('./config/config.example'));

my $queue = VM::Spawn::Queue::DBI->new(
    %{$config->{database}}
);
my $docean = VM::Spawn::Provider::DigitalOcean->new(
    %{$config->{digitalocean}}
);
my $r53 = VM::Spawn::DNS::Route53->new(
    %{$config->{route53}}
);

my $notifier = VM::Spawn::Notifier::Email->new(
    %{$config->{email_notifier}},
    fallback_lang => 'en',
    transport     => Email::Sender::Transport::SMTP->new(
        $config->{email_transport}
    )
);

my $motdsetter = VM::Spawn::AppHandler::SSHScript->new(
    %{$config->{set_motd}},
);

my $vmspawn = VM::Spawn->new(
    queue          => $queue,
    provider       => $docean,
    dns            => $r53,
    # ignore the type in both, we only have one
    apphandler_for => sub { $motdsetter },
    notifier_for   => sub { $notifier   },
    logger         => VM::Spawn::Logger::Console->new(),
    %{$config->{vmspawn}},
);

$vmspawn->process_expired;
$vmspawn->process_requested;

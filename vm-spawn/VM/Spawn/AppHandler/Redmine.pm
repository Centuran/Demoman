package VM::Spawn::AppHandler::Redmine;
use Moo;
with 'VM::Spawn::AppHandler';

use WebService::Redmine;
use Carp;
use LWP::Simple;

has 'admin_password' => (is => 'ro', required => 1);
has 'configuration'  => (is => 'ro', required => 1);

sub setup {
    my ($self, $ip_address, $opts) = @_;

    # wait until it comes up
    my $retries = 20;
    my $success;
    do {
        print STDERR "Retries left: $retries\n";
        $success = get("http://$ip_address/projects");
        sleep(10) unless $success;
    } while ($retries-- && !$success);

    unless ($success) {
        croak "VM didn't start up properly in reasonable time, aborting";
    }

    my $config = $self->configuration;

    my $rm = WebService::Redmine->new(
        host => $ip_address,
        user => 'admin',
        pass => $self->admin_password,
    );

    for my $user (@{$config->{users}}) {
        # Due to some obscure redmine bug, creating a user using the JSON
        # API results in an Internal Server Error.
        # We're left with no choice
        #
        # Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn
        # Blessed be thee, the Great Old One, son of Nug, grandson
        # of Yog-Sothoth and Shub-Niggurath, the blood of Azathoth
        my $xml = '<?xml version="1.0" encoding="UTF-8" ?><user>';
        $user->{password} .= $opts->{passwd_suffix};
        while (my ($key, $val) = each %$user) {
            $xml .= "\n  <$key>$val</$key>"
        }
        $xml .= "\n</user>\n";
        my $uri = URI->new(sprintf('%s/users.xml', $rm->{uri}));
        my $req = HTTP::Request->new('POST', $uri);
        $req->header('Content-Type'   => 'text/xml');
        $req->header('Content-Length' => length $xml);
        $req->content($xml);
        my $res = $rm->{ua}->request($req);
        unless ($res->is_success) {
            my $hint;
            if ($res->message =~ /Unauthorized/) {
                $hint = "Make sure you have REST API enabled in your "
                      . "Redmine settings";
            }
            croak "Error while creating user: " . $res->message
                  . ($hint ? " ($hint)" : "") . "\n";
        }
    }

    for my $project (@{$config->{projects}}) {
        my @issues = @{delete $project->{issues}};
        my $res = $rm->createProject({ project => $project });
        unless ($res) {
            croak "Errors creating project:\n" . join("\n    ", @{$rm->errorDetails->{errors}}) . "\n";

        }
        my $project_id = $res->{project}{id};
        for my $issue (@issues) {
            $issue->{project_id} = $project_id;
            my $res = $rm->createIssue({ issue => $issue });
            unless ($res) {
                croak "Errors creating issue\n" . join("\n    ", @{$rm->errorDetails->{errors}}) . "\n";
            }
        }
    }

    $self->notifier->notify(
        $opts->{email_address}, $opts->{email_lang}, {
            hostname      => $opts->{hostname},
            passwd_suffix => $opts->{passwd_suffix},
        }
    );
}

'stout';

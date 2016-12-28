use 5.020;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/Demoman/vm-spawn";

use DBI;
use File::Slurp;
use Try::Tiny;
use VM::Spawn::AppHandler::SSHScript;
use VM::Spawn::DNS::Route53;
use VM::Spawn::Provider::DigitalOcean;
use YAML::XS;

my $config_file = shift or die "Usage: $0 <config file>\n";
my $config = Load(scalar read_file($config_file));

my $dbfile = $config->{vmpoll}{dbfile};
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", "", "");

my $min_idle_vms = $config->{vmpoll}{min_idle_vms};

my $docean = VM::Spawn::Provider::DigitalOcean->new(%{ $config->{digitalocean} });
my $r53  = VM::Spawn::DNS::Route53->new(%{ $config->{route53} });
my $otrs = VM::Spawn::AppHandler::SSHScript->new(%{ $config->{otrs} });

sub create_symbol {
    my $id        = shift;
    my $symbol_lo = 111;
    my $symbol_hi = 999;

    $symbol_lo + ($id - 1) % ($symbol_hi - $symbol_lo + 1);
}

sub create_vm {
    my ($maxid) = $dbh->selectrow_array('select max(id) from vms');
    $maxid //= 0;
    my $symbol   = create_symbol($maxid);
    my $hostname = "$symbol." . $config->{vmpoll}{vms_domain};
    my ($ip, $vmdata) = $docean->create($hostname, 'otrs');

    #$r53->create($hostname, $ip);
    $dbh->do(
        'insert into vms (owner, hostname, ip_address, data) values (null, ?, ?, ?)',
        undef, $hostname, $ip, $vmdata
    );
    say "New VM created";
}

sub check {
    my ($idle_vms) = $dbh->selectrow_array('select count(*) from vms where owner is null');
    say "There are $idle_vms idle VMs";
    my $vms_needed = $min_idle_vms - $idle_vms;
    if ($vms_needed <= 0) {
        say "Enough VMs on standby, nothing to do";
        return;
    }
    else {
        say "Need $vms_needed new VMs";
        for (1 .. $vms_needed) {
            try {
                create_vm();
            };
        }
    }
}

while (1) {
    sleep 1;
    check;
}

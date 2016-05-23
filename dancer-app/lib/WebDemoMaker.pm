package WebDemoMaker;
use Dancer2;
use Dancer2::Plugin::Database;
use Dancer2::Plugin::Email;
use DateTime;

our $VERSION = '0.1';

post '/demo' => sub {
    my $params = params;

    content_type 'application/json';
    
    header 'access-control-allow-origin' => '*';

    if (!defined $params->{email_address}) {
        status '422';
        return to_json { error => 'E-mail address is not defined'}
    }
    
    if ($params->{email_address} !~ /^[^@]+\@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/) {
        status '422';
        return to_json { error => 'E-mail address is invalid' };
    }

    my $ip_address = request->forwarded_for_address || request->address;

    my $requested_dt = DateTime->now;

    database->quick_insert(
        'vms',
        {
            requested_on        => $requested_dt->ymd . ' ' . $requested_dt->hms,
            request_email       => $params->{email_address},
            request_language    => $params->{language},
            request_application => $params->{application},
            request_ip_address  => $ip_address,
        }
    );

    email {
        from    => config->{contact_email_from},
        to      => config->{contact_email_to},
        subject => 'New server demo request from ' . $params->{email_address},
        body    => <<"END",
E-mail address: $params->{email_address}
Language: $params->{language}
Application: $params->{application}
IP address: $ip_address
END
        type    => 'plain',
    };

    status '200';
    return to_json {
        msg => ''
    };
};

true;

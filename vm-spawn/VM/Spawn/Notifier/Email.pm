package VM::Spawn::Notifier::Email;
use Moo;
with 'VM::Spawn::Notifier';

use Email::MIME;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP;
use Mail::SendGrid::SmtpApiHeader;
use Encode qw(encode);
use IO::All;
use File::Slurp;
use Template::Tiny;

has 'transport'     => (is => 'ro', required => 1);
has 'template_dir'  => (is => 'ro', required => 1);
has 'fallback_lang' => (is => 'ro', required => 1);
has 'fallback_tmpl' => (is => 'ro');

has 'from'        => (is => 'ro', required => 1);
has 'subject'     => (is => 'ro', required => 1);
has 'attachments' => (is => 'ro', default => sub { [] });

sub BUILD {
    my $self = shift;
    my $fallback_file = sprintf "%s/email-%s.tt",
                                $self->template_dir,
                                $self->fallback_lang;
    unless (-e $fallback_file) {
        die "Fallback email template $fallback_file doesn't exist; "
            . "cannot continue";
    }
    $self->{fallback_tmpl} = $fallback_file;
}

sub notify {
    my ($self, $email_address, $lang, $payload) = @_;
    my $tt = Template::Tiny->new;
    my $template_file = $self->template_dir . "/email-$lang.tt";
    unless (-e $template_file) {
        $template_file = $self->fallback_tmpl;
        warn "No template file found for language '$lang', falling back "
             . "to $template_file\n";
    }
    my $tmpl = read_file($template_file, binmode => ':utf8');
    my $email_html;
    $tt->process(\$tmpl, $payload, \$email_html);

    my @attachments = map {
        my %meta = %{$_};
        my $content_type  = delete $meta{content_type};
        my $src_filename  = delete $meta{src_filename};
        my $dest_filename = delete $meta{dest_filename};
        Email::MIME->create(
            header => [ %meta ],
            attributes => {
                content_type => $content_type,
                encoding     => 'base64',
                disposition  => 'attachment',
                filename     => $dest_filename,
            },
            body => io($src_filename)->binary->all,
        )
    } @{$self->attachments};

    my $email = Email::MIME->create(
        attributes => {
            content_type => 'multipart/alternative',
        },
        header_str => [
            To      => $email_address,
            From    => $self->from,
            Subject => $self->subject,
        ],
        parts => [
            Email::MIME->create(
                attributes => {
                    content_type => 'text/plain',
                    charset      => 'UTF8',
                    encoding     => '8bit',
                },
                body => '',
            ),
            Email::MIME->create(
                header => [
                    'Content-Type' => 'multipart/related; type="text/html"'
                ],
                parts => [
                    Email::MIME->create(
                        attributes => {
                            content_type => 'text/html',
                            charset      => 'UTF8',
                            encoding     => '8bit',
                        },
                        body => encode('utf-8', $email_html),
                    ),
                    @attachments,
                ]
            ),
        ],
    );

    my $xsmtpapi = Mail::SendGrid::SmtpApiHeader->new;
    $xsmtpapi->addFilterSetting('clicktrack', 'enable' => 0);
    $xsmtpapi->addFilterSetting('opentrack', 'enable' => 0);
    $email->header_str_set('X-SMTPAPI', $xsmtpapi->asJSON);

    my @return = sendmail($email, { transport => $self->transport });
}

'pizza';

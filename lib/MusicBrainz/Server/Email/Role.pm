package MusicBrainz::Server::Email::Role;
use Moose::Role;
use namespace::autoclean;

use DBDefs;
use Encode qw( encode );
use MooseX::Types::Moose qw( Str );
use MusicBrainz::Server::Email;
use MusicBrainz::Server::Entity::Types;
use String::TT qw( strip );

requires 'to', 'subject';

has 'body' => (
    isa => Str,
    is => 'ro',
    builder => 'text',
    lazy => 1,
    required => 1
);

has 'from' => (
    isa => Str,
    is => 'ro',
    required => 1,
    default => $MusicBrainz::Server::Email::NOREPLY_ADDRESS
);

has 'server' => (
    isa => Str,
    is => 'ro',
    default => sprintf 'http://%s', DBDefs::WEB_SERVER
);

sub text { '' }

sub header { '' }
sub footer { '' }
sub extra_headers { () }

around 'text' => sub {
    my $next = shift;
    my ($self, @args) = @_;

    my $email = join("\n\n", map { strip($_) } grep { $_ }
        $self->header,
        $self->$next(@args),
        '-' x 80 . "\n" . $self->footer
    );
};

sub create_email {
    my $self = shift;
    return Email::MIME->create(
        header => [
            To => $self->to,
            From => $self->from,
            Subject => $self->subject
        ],
        body => encode('utf-8', $self->body),
        attributes => {
            content_type => "text/plain",
            charset      => "UTF-8",
            encoding     => "quoted-printable",
        }
    );
}

1;

package MusicBrainz::Server::Controller::WS::1::Role::ArtistCredit;
use Moose::Role;

before 'lookup' => sub
{
    my ($self, $c) = @_;

    my $release = $c->stash->{entity};

    if ($c->stash->{inc}->artist) {
        $c->model('ArtistCredit')->load($release);
        $c->model('Artist')->load($release->artist_credit->names->[0])
            if (@{ $release->artist_credit->names } == 1);
    }
};

1;

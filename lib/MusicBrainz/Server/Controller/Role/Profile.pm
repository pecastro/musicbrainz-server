package MusicBrainz::Server::Controller::Role::Profile;
use MooseX::Role::Parameterized
    -metaclass => 'MusicBrainz::Server::Controller::Role::Meta::Parameterizable';

parameter 'threshold' => (
    required => 1,
    default => 0
);

role {
    my $params = shift;
    my $threshold = $params->threshold;

    requires 'begin', 'end';

    if ($threshold > 0) {
        after 'begin' => sub {
            my ($self, $c) = @_;
            $c->stats->profile(begin => 'request');
        };

        after 'end' => sub {
            my ($self, $c) = @_;
            $c->stats->profile(end => 'request');

            for my $stat ($c->stats->report) {
                my ($depth, $name, $duration) = @$stat;
                if ($name eq 'request' && $duration > $threshold) {
                    $c->log->warn(
                        sprintf("Slow request (%.3fs): %s", $duration, $c->req->uri)
                    );
                }
            }
        };
    }
};

1;

package MusicBrainz::Server::EditSearch::Predicate::Date;
use Moose;
use namespace::autoclean;
use feature 'switch';

use DateTime::Format::Natural;
use DateTime::Format::Pg;

# Happens to share the same operators as ID searches, just handles the
# input slightly differently
extends 'MusicBrainz::Server::EditSearch::Predicate::ID';
with 'MusicBrainz::Server::EditSearch::Predicate';

sub transform_user_input {
    my ($self, $argument) = @_;
    my $parser = DateTime::Format::Natural->new;
    DateTime::Format::Pg->format_datetime($parser->parse_datetime($argument));
}

sub valid {
    my $self = shift;
    my $parser = DateTime::Format::Natural->new;
    for my $arg_index (1.. $self->operator_cardinality($self->operator)) {
        my $arg = $self->argument($arg_index - 1) or return;
        $parser->parse_datetime($arg);
        $parser->success or return;
    }

    return 1;
}

1;

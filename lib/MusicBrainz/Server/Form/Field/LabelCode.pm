package MusicBrainz::Server::Form::Field::LabelCode;
use HTML::FormHandler::Moose;

use MusicBrainz::Server::Translation qw( l );

extends 'HTML::FormHandler::Field::Integer';

apply(
    [
        {
            check   => sub { $_[0] > 0 && $_[0] < 100000 },
            message => sub {
                my ( $value, $field ) = @_;
                return l('Label codes must be greater than 0 and 5 digits at most');
            },
        }
    ]
);

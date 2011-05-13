package MusicBrainz::Server::Form::Merge::Release;
use HTML::FormHandler::Moose;
use MusicBrainz::Server::Translation qw( l );

extends 'MusicBrainz::Server::Form::Merge';

has_field 'merge_strategy' => (
    type => 'Select',
    required => 1
);

has_field 'medium_positions' => (
    type => 'Compound',
    apply => [{
        transform => sub {
            my $value = shift;
            return {
                map {
                    $_->{id} => $_->{position}
                } @{ $value->{map} }
            }
        }
    }]
);

has_field 'medium_positions.map' => (
    type => 'Repeatable'
);

has_field 'medium_positions.map.id' => (
    type => 'Integer',
);

has_field 'medium_positions.map.position' => (
    type => 'Integer',
);

sub edit_field_names { qw(merge_strategy medium_positions) }

sub options_merge_strategy {
    return [
        $MusicBrainz::Server::Data::Release::MERGE_APPEND, l('Append mediums to target release'),
        $MusicBrainz::Server::Data::Release::MERGE_MERGE, l('Merge mediums and recordings')
    ]
}

sub validate {
    my ($self) = @_;
    if($self->field('merge_strategy')->value == $MusicBrainz::Server::Data::Release::MERGE_APPEND) {
        my (%seen_pos, %positions);
        for my $field ($self->field('medium_positions.map')->fields) {
            my $pos_field = $field->field('position');
            $pos_field->add_error(l('Another medium is already in this position'))
                if exists $seen_pos{$pos_field->value};

            $pos_field->add_error(l('Positions must be greater than 0'))
                if $pos_field->value < 1;

            $seen_pos{ $pos_field->value }++;
            $positions{$field->field('id')->value} = $pos_field->value;
        }
    }
}

1;

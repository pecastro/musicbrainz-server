package MusicBrainz::Server::EditSearch::Predicate::LinkedEntity;
use MooseX::Role::Parameterized;
use namespace::autoclean;
use feature 'switch';

use MooseX::Types::Moose qw( Str );

parameter type => (
    required => 1
);

role {
    my $params = shift;
    my $type = $params->type;

    has name => (
        is => 'ro',
        isa => Str,
        required => 1
    );

    method operator_cardinality_map => sub {
        return (
            '=' => 1,
            '!=' => 1
        );
    };

    method combine_with_query => sub {
        my ($self, $query) = @_;
        my $join_idx = $query->inc_joins;
        my $table = join('_', 'edit', $params->type);
        my $column = $params->type;
        my $alias = $table . $join_idx;
        $query->add_join("JOIN $table $alias ON $alias.edit = edit.id");

        given($self->operator) {
            when('=') {
                $query->add_where([
                    "$alias.$column = ?", $self->sql_arguments
                ]);
            }

            when ('!=') {
                $query->add_where([
                    "$alias.$column != ?", $self->sql_arguments
                ]);
            }
        };
    };
};

for my $type (qw( artist label recording release release_group work )){
    Moose::Meta::Class->create(
        'MusicBrainz::Server::EditSearch::Predicate::' . ucfirst($type),
        superclasses => [ 'Moose::Object' ],
        roles => [
            'MusicBrainz::Server::EditSearch::Predicate::LinkedEntity' => {
                type => $type
            },
            'MusicBrainz::Server::EditSearch::Predicate',
        ]
    )->name
}

1;

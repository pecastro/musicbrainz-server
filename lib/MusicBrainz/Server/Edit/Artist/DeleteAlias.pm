package MusicBrainz::Server::Edit::Artist::DeleteAlias;
use Moose;

use MusicBrainz::Server::Constants qw( $EDIT_ARTIST_DELETE_ALIAS );
use MusicBrainz::Server::Translation qw ( l ln );

extends 'MusicBrainz::Server::Edit::Alias::Delete';
with 'MusicBrainz::Server::Edit::Artist';

use aliased 'MusicBrainz::Server::Entity::Artist';

sub _alias_model { shift->c->model('Artist')->alias }

sub edit_name { l('Remove artist alias') }
sub edit_type { $EDIT_ARTIST_DELETE_ALIAS }

sub related_entities { { artist => [ shift->artist_id ] } }

sub adjust_edit_pending
{
    my ($self, $adjust) = @_;

    $self->c->model('Artist')->adjust_edit_pending($adjust, $self->artist_id);
    $self->c->model('Artist')->alias->adjust_edit_pending($adjust, $self->alias_id);
}

has 'artist_id' => (
    isa => 'Int',
    is => 'rw',
    lazy => 1,
    default => sub { shift->data->{entity}{id} }
);

sub foreign_keys
{
    my $self = shift;
    return {
        Artist => [ $self->artist_id ],
    };
}

around 'build_display_data' => sub
{
    my $orig = shift;
    my ($self, $loaded) = @_;

    my $data = $self->$orig($loaded);
    $data->{artist} = $loaded->{Artist}->{ $self->artist_id }
        || Artist->new(name => $self->data->{entity}{name});

    return $data;
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;

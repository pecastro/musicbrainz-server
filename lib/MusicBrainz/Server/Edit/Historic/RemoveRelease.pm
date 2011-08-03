package MusicBrainz::Server::Edit::Historic::RemoveRelease;
use strict;
use warnings;

use aliased 'MusicBrainz::Server::Entity::ArtistCredit';
use aliased 'MusicBrainz::Server::Entity::ArtistCreditName';
use aliased 'MusicBrainz::Server::Entity::Release';

use MusicBrainz::Server::Constants qw( $EDIT_HISTORIC_REMOVE_RELEASE );
use MusicBrainz::Server::Translation qw ( l ln );

use MusicBrainz::Server::Edit::Historic::Base;

sub edit_name     { l('Remove release') }
sub edit_template { 'historic/remove_release' }
sub historic_type { 12 }
sub edit_type     { $EDIT_HISTORIC_REMOVE_RELEASE }

sub _build_related_entities
{
    my $self = shift;
    return {
        release => $self->data->{release_ids}
    }
}

sub foreign_keys
{
    my $self = shift;
    return {
        Release => { map { $_ => [ 'ArtistCredit' ] } @{ $self->data->{release_ids} } },
        Artist  => [ $self->data->{artist_id} ]
    }
}

sub build_display_data
{
    my ($self, $loaded) = @_;

    my $data = {
        name     => $self->data->{name},
        releases => [
            map {
                $loaded->{Release}->{$_} || Release->new( name => $self->data->{name} )
            } @{ $self->data->{release_ids} }
        ]
    };

    if (my $artist = $loaded->{Artist}->{ $self->data->{artist_id} }) {
        $data->{artist_credit} = ArtistCredit->new( names => [
            ArtistCreditName->new(
                name   => $artist->name,
                artist => $artist
            )
        ]);
    }

    return $data;
}

sub upgrade
{
    my $self = shift;
    $self->data({
        release_ids => $self->album_release_ids($self->row_id),
        name        => $self->previous_value,
        artist_id   => $self->artist_id,
    });

    return $self;
}

sub deserialize_new_value {
    my ($self, $value ) = @_;
    return $value;
}

sub deserialize_previous_value {
    my ($self, $value ) = @_;
    return $value;
}

1;

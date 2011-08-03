package MusicBrainz::Server::Edit::Historic::RemoveDiscID;
use strict;
use warnings;

use aliased 'MusicBrainz::Server::Entity::CDTOC';
use MusicBrainz::Server::Constants qw( $EDIT_HISTORIC_REMOVE_DISCID );
use MusicBrainz::Server::Translation qw ( l ln );

use MusicBrainz::Server::Edit::Historic::Base;

sub edit_name     { l('Remove disc ID') }
sub historic_type { 20 }
sub edit_type     { $EDIT_HISTORIC_REMOVE_DISCID }
sub edit_template { 'historic/remove_disc_id' }

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
        Release => { map { $_ => [ 'ArtistCredit' ] } @{ $self->data->{release_ids} } }
    }
}

sub build_display_data
{
    my ($self, $loaded) = @_;
    return {
        releases => [ map { $loaded->{Release}->{$_} } @{ $self->data->{release_ids} } ],
        cdtoc    => CDTOC->new(discid => $self->data->{disc_id})
    }
}

sub upgrade
{
    my $self = shift;
    $self->data({
        release_ids => $self->album_release_ids($self->new_value->{AlbumId}),
        full_toc    => $self->new_value->{FullToc},
        disc_id     => $self->previous_value,
        cdtoc_id    => $self->new_value->{CDTOCId}
    });

    return $self;
}

sub deserialize_previous_value { my $self = shift; return shift; }
sub deserialize_new_value {
    my ($self, $value) = @_;
    if ($value eq 'DELETE') {
        return { FullToc => '', CDTOCId => 0, AlbumId => 0 }
    }
    else {
        $self->deserialize($value);
    }
}

1;

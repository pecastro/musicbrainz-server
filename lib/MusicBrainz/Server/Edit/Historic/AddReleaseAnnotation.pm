package MusicBrainz::Server::Edit::Historic::AddReleaseAnnotation;
use strict;
use warnings;

use MusicBrainz::Server::Constants qw( $EDIT_HISTORIC_ADD_RELEASE_ANNOTATION );
use MusicBrainz::Server::Edit::Types qw( Nullable );
use MusicBrainz::Server::Translation qw ( l ln );

use aliased 'MusicBrainz::Server::Entity::Release';

use MusicBrainz::Server::Edit::Historic::Base;

sub edit_name { l('Add release annotation') }
sub historic_type { 31 }
sub edit_type { $EDIT_HISTORIC_ADD_RELEASE_ANNOTATION }
sub edit_template { 'historic/add_release_annotation' }

sub _build_related_entities {
    my $self = shift;
    return {
        release => $self->data->{release_ids}
    }
}

sub upgrade
{
    my $self = shift;
    $self->data({
        release_ids => $self->album_release_ids($self->row_id),
        text => $self->new_value->{Text},
        changelog => $self->new_value->{ChangeLog}
    });
    return $self;
};

sub foreign_keys
{
    my $self = shift;
    return {
        Release => { map { $_ => [ 'ArtistCredit' ] } @{ $self->data->{release_ids} } }
    };
}

sub build_display_data
{
    my ($self, $loaded) = @_;
    return {
        releases => [ map {
            $loaded->{Release}{$_}
        } @{ $self->data->{release_ids} } ],
        annotation => $self->data->{text},
        changelog => $self->data->{changelog}
    };
}

1;


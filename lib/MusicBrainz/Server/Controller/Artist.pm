package MusicBrainz::Server::Controller::Artist;
use Moose;

BEGIN { extends 'MusicBrainz::Server::Controller'; }

with 'MusicBrainz::Server::Controller::Role::Load' => {
    model       => 'Artist',
};
with 'MusicBrainz::Server::Controller::Role::LoadWithRowID';
with 'MusicBrainz::Server::Controller::Role::Annotation';
with 'MusicBrainz::Server::Controller::Role::Alias';
with 'MusicBrainz::Server::Controller::Role::Details';
with 'MusicBrainz::Server::Controller::Role::EditListing';
with 'MusicBrainz::Server::Controller::Role::Relationship';
with 'MusicBrainz::Server::Controller::Role::Rating';
with 'MusicBrainz::Server::Controller::Role::Tag';
with 'MusicBrainz::Server::Controller::Role::Subscribe';

use Data::Page;
use HTTP::Status qw( :constants );
use MusicBrainz::Server::Constants qw( $DARTIST_ID $VARTIST_ID $EDIT_ARTIST_MERGE );
use MusicBrainz::Server::Constants qw( $EDIT_ARTIST_CREATE $EDIT_ARTIST_EDIT $EDIT_ARTIST_DELETE );
use MusicBrainz::Server::Form::Artist;
use MusicBrainz::Server::Form::Confirm;
use Sql;

=head1 NAME

MusicBrainz::Server::Controller::Artist - Catalyst Controller for working
with Artist entities

=head1 DESCRIPTION

The artist controller is used for interacting with
L<MusicBrainz::Server::Artist> entities - both read and write. It provides
views to the artist data itself, and a means to navigate to a release
that is attributed to a certain artist.

=head1 ACTIONS

=head2 READ ONLY PAGES

The follow pages can are all read only.

=head2 base

Base action to specify that all actions live in the C<artist>
namespace

=cut

sub base : Chained('/') PathPart('artist') CaptureArgs(0) { }

=head2 artist

Extends loading by disallowing the access of the special artist
C<DELETED_ARTIST>, and fetching any extra data required in
the artist header.

=cut

after 'load' => sub
{
    my ($self, $c) = @_;

    my $artist = $c->stash->{artist};
    if ($artist->id == $DARTIST_ID)
    {
        $c->detach('/error_404');
    }

    my $artist_model = $c->model('Artist');
    $artist_model->load_meta($artist);
    if ($c->user_exists) {
        $artist_model->rating->load_user_ratings($c->user->id, $artist);

        $c->stash->{subscribed} = $artist_model->subscription->check_subscription(
            $c->user->id, $artist->id);
    }

    $c->model('ArtistType')->load($artist);
    $c->model('Gender')->load($artist);
    $c->model('Country')->load($artist);

    $c->stash(
        watching_artist =>
            $c->user_exists && $c->model('WatchArtist')->is_watching(
                editor_id => $c->user->id, artist_id => $artist->id
            )
    );
};

=head2 similar

Display artists similar to this artist

=cut

sub similar : Chained('load')
{
    my ($self, $c) = @_;
    my $artist = $self->entity;

    $c->stash->{similar_artists} = $c->model('Artist')->find_similar_artists($artist);
}

=head2 relations

Shows all the entities (except track) that this artist is related to.

=cut

sub relations : Chained('load')
{
    my ($self, $c) = @_;
    my $artist = $self->entity;

    $c->stash->{relations} = $c->model('Relation')->load_relations($artist, to_type => [ 'artist', 'url', 'label', 'album' ]);
}

=head2 appearances

Display a list of releases that an artist appears on via advanced
relations.

=cut

sub appearances : Chained('load')
{
    my ($self, $c) = @_;
    my $artist = $self->entity;

    $c->stash->{releases} = $c->model('Release')->find_linked_albums($artist);
}

=head2 show

Shows an artist's main landing page.

This page shows the main releases (by default) of an artist, along with a
summary of advanced relations this artist is involved in. It also shows
folksonomy information (tags).

=cut

sub show : PathPart('') Chained('load')
{
    my ($self, $c) = @_;

    my $artist = $c->stash->{artist};
    my $release_groups;
    if ($c->stash->{artist}->id == $VARTIST_ID)
    {
        my $index = $c->req->query_params->{index};
        if ($index) {
            $release_groups = $self->_load_paged($c, sub {
                $c->model('ReleaseGroup')->find_by_name_prefix_va($index, shift,
                                                                  shift);
            });
        }
        $c->stash(
            template => 'artist/browse_various.tt',
            index    => $index,
        );
    }
    else
    {
        my $method = 'find_by_artist';
        my $show_va = $c->req->query_params->{va};
        if ($show_va) {
            $method = 'find_by_track_artist';
        }

        $release_groups = $self->_load_paged($c, sub {
                $c->model('ReleaseGroup')->$method($c->stash->{artist}->id, shift, shift);
            });

        my $pager = $c->stash->{pager};
        if (!$show_va && $pager->total_entries == 0) {
            $release_groups = $self->_load_paged($c, sub {
                    $c->model('ReleaseGroup')->find_by_track_artist($c->stash->{artist}->id, shift, shift);
                });
            $c->stash(
                va_only => 1
            );
        }

        $c->stash(
            show_va => $show_va,
            template => 'artist/index.tt'
        );
    }

    if ($c->user_exists) {
        $c->model('ReleaseGroup')->rating->load_user_ratings($c->user->id, @$release_groups);
    }

    $c->model('ArtistCredit')->load(@$release_groups);
    $c->model('ReleaseGroupType')->load(@$release_groups);
    $c->stash(
        release_groups => $release_groups,
        show_artists => scalar grep {
            $_->artist_credit->name ne $artist->name
        } @$release_groups,
    );
}

=head2 works

Shows all works of an artist. For various artists, the results would be
browsable (not just paginated)

=cut

sub works : Chained('load')
{
    my ($self, $c) = @_;
    my $artist = $c->stash->{artist};
    my $grouped_works = $self->_load_paged($c, sub {
        $c->model('Work')->find_by_artist($c->stash->{artist}->id, shift, shift);
    });
    my @works = map { @{ $_->{works} } } @$grouped_works;
    $c->model('Artist')->load_for_works(@works);
    if ($c->user_exists) {
        $c->model('Work')->rating->load_user_ratings($c->user->id, @works);
    }
    $c->stash( grouped_works => $grouped_works );
}

=head2 recordings

Shows all recordings of an artist. For various artists, the results would be
browsable (not just paginated)

=cut

sub recordings : Chained('load')
{
    my ($self, $c) = @_;

    my $artist = $c->stash->{artist};
    my $recordings;

    if ($artist->id == $VARTIST_ID)
    {
        my $index = $c->req->query_params->{index};
        if ($index) {
            $recordings = $self->_load_paged($c, sub {
                $c->model('Recording')->find_by_name_prefix_va($index, shift, shift);
            });
        }
        $c->stash(
            template => 'artist/browse_various_recordings.tt',
            index    => $index,
        );
    }
    else
    {
        $recordings = $self->_load_paged($c, sub {
                $c->model('Recording')->find_by_artist($artist->id, shift, shift);
            });
        $c->model('Recording')->load_meta(@$recordings);

        if ($c->user_exists) {
            $c->model('Recording')->rating->load_user_ratings($c->user->id, @$recordings);
        }

        $c->stash( template => 'artist/recordings.tt' );
    }

    $c->model('ISRC')->load_for_recordings(@$recordings);
    $c->model('ArtistCredit')->load(@$recordings);

    $c->stash(
        recordings => $recordings,
        show_artists => scalar grep {
            $_->artist_credit->name ne $artist->name
        } @$recordings,
    );
}

sub standalone_recordings : Chained('load') PathPart('standalone-recordings')
{
    my ($self, $c) = @_;

    my $artist = $c->stash->{artist};
    my $standalones = $self->_load_paged($c, sub {
        $c->model('Recording')->find_standalone($artist->id, shift, shift);
    });

    $c->model('ISRC')->load_for_recordings(@$standalones);
    $c->model('ArtistCredit')->load(@$standalones);

    $c->stash(
        recordings => $standalones,
        show_artists => scalar grep {
            $_->artist_credit->name ne $artist->name
        } @$standalones,
    );
}

=head2 releases

Shows all releases of an artist.

=cut

sub releases : Chained('load')
{
    my ($self, $c) = @_;

    my $artist = $c->stash->{artist};
    my $releases;

    if ($artist->id == $VARTIST_ID)
    {
        my $index = $c->req->query_params->{index};
        if ($index) {
            $releases = $self->_load_paged($c, sub {
                $c->model('Release')->find_by_name_prefix_va($index, shift,
                                                                  shift);
            });
        }
        $c->stash(
            template => 'artist/browse_various_releases.tt',
            index    => $index,
        );
    }
    else
    {
        my $method = 'find_by_artist';
        my $show_va = $c->req->query_params->{va};
        if ($show_va) {
            $method = 'find_by_track_artist';
            $c->stash( show_va => 1 );
        }

        $releases = $self->_load_paged($c, sub {
                $c->model('Release')->$method($artist->id, shift, shift);
            });

        my $pager = $c->stash->{pager};
        if (!$show_va && $pager->total_entries == 0) {
            $releases = $self->_load_paged($c, sub {
                    $c->model('Release')->find_by_track_artist($c->stash->{artist}->id, shift, shift);
                });
            $c->stash(
                va_only => 1,
                show_va => 1
            );
        }

        $c->stash( template => 'artist/releases.tt' );
    }

    $c->model('ArtistCredit')->load(@$releases);
    $c->model('Medium')->load_for_releases(@$releases);
    $c->model('MediumFormat')->load(map { $_->all_mediums } @$releases);
    $c->model('Country')->load(@$releases);
    $c->model('ReleaseLabel')->load(@$releases);
    $c->model('Label')->load(map { $_->all_labels } @$releases);
    $c->stash(
        releases => $releases,
        show_artists => scalar grep {
            $_->artist_credit->name ne $artist->name
        } @$releases,
    );
}

=head2 WRITE METHODS

These methods write to the database (create/update/delete)

=head2 create

When given a GET request this displays a form allowing the user to enter
data, creating a new artist. If a POST request is received, the data
is validated and if validation succeeds, the artist is entered into the
MusicBrainz database.

The heavy work validating the form and entering data into the database
is done via L<MusicBrainz::Server::Form::Artist>

=cut

with 'MusicBrainz::Server::Controller::Role::Create' => {
    form      => 'Artist',
    edit_type => $EDIT_ARTIST_CREATE,
};

=head2 edit

Allows users to edit the data about this artist.

When viewed with a GET request, the user is displayed a form filled with
the current artist data. When a POST request is received, the data is
validated and if it passed validation is the updated data is entered
into the MusicBrainz database.

=cut

with 'MusicBrainz::Server::Controller::Role::Edit' => {
    form           => 'Artist',
    edit_type      => $EDIT_ARTIST_EDIT,
};

=head2 add_release

Add a new release to this artist.

=cut

sub add_release : Chained('load')
{
    my ($self, $c) = @_;
    $c->forward('/user/login');
    $c->forward('/release_editor/add_release');
}

=head2 merge

Merge 2 artists into a single artist

=cut

with 'MusicBrainz::Server::Controller::Role::Merge' => {
    edit_type => $EDIT_ARTIST_MERGE,
    merge_form => 'Merge::Artist'
};

=head2 rating

Rate an artist

=cut

sub rating : Chained('load') Args(2)
{
    my ($self, $c, $entity, $new_vote) = @_;
    #Need more validation here

    $c->forward('/user/login');
    $c->forward('/rating/do_rating', ['artist', $entity, $new_vote] );
    $c->response->redirect($c->entity_url($self->entity, 'show'));
}

=head2 import

Import a release from another source (such as FreeDB)

=cut

sub import : Local
{
    my ($self, $c) = @_;
    die "This is a stub method";
}

around $_ => sub {
    my $orig = shift;
    my ($self, $c) = @_;

    my $artist = $c->stash->{artist};
    if ($artist->is_special_purpose) {
        $c->stash( template => 'artist/special_purpose.tt' );
        $c->response->status(HTTP_FORBIDDEN);
        $c->detach;
    }
    else {
        $self->$orig($c);
    }
} for qw( edit );

sub watch : Chained('load') RequireAuth {
    my ($self, $c) = @_;

    my $artist = $c->stash->{artist};
    $c->model('WatchArtist')->watch_artist(
        artist_id => $artist->id,
        editor_id => $c->user->id
    ) if $c->user_exists;

    $c->response->redirect($c->req->referer);
}

sub stop_watching : Chained('load') RequireAuth {
    my ($self, $c) = @_;

    my $artist = $c->stash->{artist};
    $c->model('WatchArtist')->stop_watching_artist(
        artist_ids => [ $artist->id ],
        editor_id => $c->user->id
    ) if $c->user_exists;

    $c->response->redirect($c->req->referer);
}

=head1 LICENSE

This software is provided "as is", without warranty of any kind, express or
implied, including  but not limited  to the warranties of  merchantability,
fitness for a particular purpose and noninfringement. In no event shall the
authors or  copyright  holders be  liable for any claim,  damages or  other
liability, whether  in an  action of  contract, tort  or otherwise, arising
from,  out of  or in  connection with  the software or  the  use  or  other
dealings in the software.

GPL - The GNU General Public License    http://www.gnu.org/licenses/gpl.txt
Permits anyone the right to use and modify the software without limitations
as long as proper  credits are given  and the original  and modified source
code are included. Requires  that the final product, software derivate from
the original  source or any  software  utilizing a GPL  component, such  as
this, is also licensed under the GPL license.

=cut

1;

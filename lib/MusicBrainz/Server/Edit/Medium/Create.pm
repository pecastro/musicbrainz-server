package MusicBrainz::Server::Edit::Medium::Create;
use Carp;
use Moose;
use MooseX::Types::Moose qw( ArrayRef Str Int );
use MooseX::Types::Structured qw( Dict Optional );
use MusicBrainz::Server::Constants qw( $EDIT_MEDIUM_CREATE );
use MusicBrainz::Server::Edit::Medium::Util ':all';
use MusicBrainz::Server::Edit::Types qw(
    ArtistCreditDefinition
    Nullable
    NullableOnPreview
);
use MusicBrainz::Server::Edit::Utils qw( verify_artist_credits );
use MusicBrainz::Server::Entity::Medium;
use MusicBrainz::Server::Translation qw( l ln );

extends 'MusicBrainz::Server::Edit::Generic::Create';
with 'MusicBrainz::Server::Edit::Role::Preview';
with 'MusicBrainz::Server::Edit::Medium::RelatedEntities';
with 'MusicBrainz::Server::Edit::Medium';

use aliased 'MusicBrainz::Server::Entity::Release';

sub edit_type { $EDIT_MEDIUM_CREATE }
sub edit_name { l('Add medium') }
sub _create_model { 'Medium' }
sub medium_id { shift->entity_id }

has '+data' => (
    isa => Dict[
        name         => Optional[Str],
        format_id    => Optional[Int],
        position     => Int,
        release      => NullableOnPreview[Dict[
            id => Int,
            name => Str
        ]],
        tracklist    => ArrayRef[track()]
    ]
);

around _build_related_entities => sub {
    my ($orig, $self) = splice(@_, 0, 2);
    my $related = $self->$orig(@_);

    push @{ $related->{artist} }, map {
        map { $_->{artist}{id} } @{ $_->{artist_credit}->{names} }
    } @{ $self->data->{tracklist} };

    return $related;
};

sub alter_edit_pending
{
    my $self = shift;
    return {
        'Medium' => [ $self->entity_id ],
        'Release' => [ $self->data->{release}->{id} ]
    }
}

sub initialize {
    my ($self, %opts) = @_;

    my $tracklist = delete $opts{tracklist};
    $opts{tracklist} = tracks_to_hash($tracklist);

    unless ($self->preview) {
        my $release = delete $opts{release} or die 'Missing "release" argument';
        $opts{release} = {
            id => $release->id,
            name => $release->name
        };
    }

    $self->data(\%opts);
}

sub foreign_keys
{
    my $self = shift;

    my %fk;
    $fk{MediumFormat} = { $self->data->{format_id} => [] } if $self->data->{format_id};
    $fk{Release} = { $self->data->{release}{id} => [ 'ArtistCredit' ] }
        if $self->data->{release};

    tracklist_foreign_keys(\%fk, $self->data->{tracklist});

    return \%fk;
}

sub build_display_data
{
    my ($self, $loaded) = @_;

    my $medium = $self->entity_id && $self->c->model('Medium')->get_by_id($self->entity_id);
    if ($medium)
    {
        $self->c->model('Release')->load($medium);
        $self->c->model('ArtistCredit')->load($medium->release);
    }

    my $format = $self->data->{format_id};

    my $data = {
        name         => $self->data->{name} || '',
        format       => $format ? $loaded->{MediumFormat}->{ $format } : '',
        position     => $self->data->{position},
        tracklist    => display_tracklist($loaded, $self->data->{tracklist}),
        release      => $medium ? $medium->release : undef,
    };

    if (!$self->preview) {
        $data->{release} = $loaded->{Release}->{ $self->data->{release}{id} }
            || Release->new( name => $self->data->{release}{name} );
    }

    return $data;
}

sub _insert_hash {
    my ($self, $data) = @_;

    # Create related data (artist credits and recordings)
    my $tracklist = delete $data->{tracklist};

    verify_artist_credits($self->c, map {
        $_->{artist_credit}
    } @$tracklist);

    for my $track (@$tracklist) {
        $track->{recording_id} ||= $self->c->model('Recording')->insert({
            %$track,
            artist_credit => $self->c->model('ArtistCredit')->find_or_insert($track->{artist_credit}),
        })->id;
    }

    $data->{tracklist_id} = $self->c->model('Tracklist')->find_or_insert($tracklist)->id;

    my $release = delete $data->{release};
    $data->{release_id} = $release->{id};

    return $data;
}

around reject => sub {
    my ($orig, $self) = splice(@_, 0, 2);

    # Find the medium and get its tracklist
    my $medium = $self->c->model('Medium')->get_by_id($self->entity_id);
    $self->c->model('Track')->load_for_tracklists($medium->tracklist);

    # Now we can remove the medium and tracklist
    $self->$orig(@_);
    $self->c->model('Tracklist')->garbage_collect;

    # And now clean up any orphaned recordings
    my $track_index = -1;
    my @recordings_to_delete;
    for my $track ($medium->tracklist->all_tracks) {
        $track_index++;

        # Dont delete recordings we didnt create
        next if $self->data->{tracklist}[ $track_index ]{recording_id};

        # XXX FIXME Turn n queries into 1 query
        next unless $self->c->model('Recording')->can_delete($track->recording_id);

        push @recordings_to_delete, $track->recording_id;
    };


    $self->c->model('Recording')->delete(@recordings_to_delete)
        if @recordings_to_delete;
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;


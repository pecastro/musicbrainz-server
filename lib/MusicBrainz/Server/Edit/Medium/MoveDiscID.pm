package MusicBrainz::Server::Edit::Medium::MoveDiscID;
use Moose;
use namespace::autoclean;

use MusicBrainz::Server::Constants qw( $EDIT_MEDIUM_MOVE_DISCID );
use MusicBrainz::Server::Edit::Exceptions;
use MusicBrainz::Server::Translation qw( l ln );
use MooseX::Types::Moose qw( Int Str );
use MooseX::Types::Structured qw( Dict );

extends 'MusicBrainz::Server::Edit';
with 'MusicBrainz::Server::Edit::Medium';

use aliased 'MusicBrainz::Server::Entity::CDTOC';
use aliased 'MusicBrainz::Server::Entity::MediumCDTOC';
use aliased 'MusicBrainz::Server::Entity::Release';

sub edit_name { l('Move disc ID') }
sub edit_type { $EDIT_MEDIUM_MOVE_DISCID }

has '+data' => (
    isa => Dict[
        medium_cdtoc => Dict[
            id => Int,
            toc => Str
        ],
        old_medium => Dict[
            id => Int,
            release => Dict[
                name => Str,
                id => Int
            ]
        ],
        new_medium => Dict[
            id => Int,
            release => Dict[
                name => Str,
                id => Int
            ]
        ],
    ]
);

sub release_ids
{
    my $self = shift;
    return (
        $self->data->{old_medium}{release}{id},
        $self->data->{new_medium}{release}{id}
    );
}

sub alter_edit_pending
{
    my ($self) = @_;
    return {
        Release => [ $self->release_ids ],
        MediumCDTOC => [ $self->data->{medium_cdtoc}{id} ]
    };
}

sub _build_related_entities
{
    my $self = shift;
    return { 
        release => [ $self->release_ids ],
    }
}

sub foreign_keys
{
    my $self = shift;
    return {
        Release => { map { $_ => [ 'ArtistCredit' ] } $self->release_ids },
        MediumCDTOC => { $self->data->{medium_cdtoc_id} => [ 'CDTOC' ] },
        Medium => {
            $self->data->{new_medium}{id} => [ 'MediumFormat', 'Release' ],
            $self->data->{old_medium}{id} => [ 'MediumFormat', 'Release' ]
        }
    }
}

sub build_display_data
{
    my ($self, $loaded) = @_;
    return {
        medium_cdtoc => $loaded->{MediumCDTOC}->{ $self->data->{medium_cdtoc}{id} }
            || MediumCDTOC->new(
                cdtoc => CDTOC->new_from_toc($self->data->{medium_cdtoc}{toc})
            ),
        old_release => $loaded->{Release}->{ $self->data->{old_medium}{release}{id} }
            || Release->new( name => $self->data->{old_medium}{release}{name} ),
        new_release => $loaded->{Release}->{ $self->data->{new_medium}{release}{id} }
            || Release->new( name => $self->data->{new_medium}{release}{name} ),
        new_medium  => $loaded->{Medium}{ $self->data->{new_medium}{id} },
        old_medium  => $loaded->{Medium}{ $self->data->{old_medium}{id} },
    }
}

sub initialize
{
    my ($self, %opts) = @_;
    my $new = $opts{new_medium} or die 'No new medium';
    my $medium_cdtoc = $opts{medium_cdtoc} or die 'No medium_cdtoc';

    unless ($medium_cdtoc->cdtoc) {
        $self->c->model('CDTOC')->load($medium_cdtoc);
    }

    $self->data({
        medium_cdtoc => {
            id => $medium_cdtoc->id,
            toc => $medium_cdtoc->cdtoc->toc
        },
        old_medium => {
            id => $medium_cdtoc->medium->id,
            release => {
                id => $medium_cdtoc->medium->release->id,
                name => $medium_cdtoc->medium->release->name,
            }
        },
        new_medium => {
            id => $new->id,
            release => {
                id => $new->release->id,
                name => $new->release->name
            }
        }
    });
}

sub accept
{
    my $self = shift;
    my $medium = $self->c->model('Medium')->get_by_id($self->data->{new_medium}{id})
        or MusicBrainz::Server::Edit::Exceptions::FailedDependency->throw(
            'The target medium no longer exists'
        );

    my $medium_cdtoc = $self->c->model('MediumCDTOC')->get_by_id($self->data->{medium_cdtoc}{id});
    $self->c->model('CDTOC')->load($medium_cdtoc);

    $self->c->model('MediumCDTOC')->update(
        $self->data->{medium_cdtoc}{id},
        { medium_id => $medium->id  }
    ) unless $self->c->model('MediumCDTOC')->medium_has_cdtoc(
        $medium->id,
        $medium_cdtoc->cdtoc
    );
}

__PACKAGE__->meta->make_immutable;
1;

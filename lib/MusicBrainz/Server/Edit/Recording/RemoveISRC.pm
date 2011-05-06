package MusicBrainz::Server::Edit::Recording::RemoveISRC;
use Moose;
use Method::Signatures::Simple;
use MooseX::Types::Moose qw( Int Str );
use MooseX::Types::Structured qw( Dict );
use MusicBrainz::Server::Constants qw( $EDIT_RECORDING_REMOVE_ISRC );
use MusicBrainz::Server::Constants qw( :expire_action :quality );
use MusicBrainz::Server::Translation qw( l ln );

use aliased 'MusicBrainz::Server::Entity::Recording';
use aliased 'MusicBrainz::Server::Entity::ISRC';

extends 'MusicBrainz::Server::Edit';
with 'MusicBrainz::Server::Edit::Recording::RelatedEntities';
with 'MusicBrainz::Server::Edit::Recording';

sub edit_name { l('Remove ISRC') }
sub edit_type { $EDIT_RECORDING_REMOVE_ISRC }

sub edit_conditions
{
    return {
        $QUALITY_LOW => {
            duration      => 4,
            votes         => 1,
            expire_action => $EXPIRE_ACCEPT,
            auto_edit     => 0,
        },
        $QUALITY_NORMAL => {
            duration      => 14,
            votes         => 3,
            expire_action => $EXPIRE_ACCEPT,
            auto_edit     => 0,
        },
        $QUALITY_HIGH => {
            duration      => 14,
            votes         => 4,
            expire_action => $EXPIRE_REJECT,
            auto_edit     => 0,
        },
    };
}

sub recording_id { shift->data->{recording}{id} }

has '+data' => (
    isa => Dict[
        isrc => Dict[
            id   => Int,
            isrc => Str
        ],
        recording => Dict[
            id   => Int,
            name => Str
        ]
    ]
);

method alter_edit_pending
{
    return {
        Recording => [ $self->data->{recording}{id} ]
    }
}

method foreign_keys
{
    return {
        ISRC      => [ $self->data->{isrc}{id} ],
        Recording => { $self->data->{recording}{id} => [ 'ArtistCredit'] }
    }
}

method build_display_data ($loaded)
{
    my $isrc = $loaded->{ISRC}{ $self->data->{isrc}{id} } ||
        ISRC->new( isrc => $self->data->{isrc}{isrc} );

    my $recording = $loaded->{Recording}{ $self->data->{recording}{id} } ||
        Recording->new( name => $self->data->{recording}{name} );

    $isrc->recording($recording);

    return { isrc => $isrc };
}

sub initialize
{
    my ($self, %opts) = @_;

    my $isrc = $opts{isrc} or die "Required 'isrc' object missing";
    $self->c->model('Recording')->load($isrc) unless defined $isrc->recording;
    $self->data({
        isrc => {
            id   => $isrc->id,
            isrc => $isrc->isrc,
        },
        recording => {
            id   => $isrc->recording->id,
            name => $isrc->recording->name
        }
    });
}

method accept
{
    $self->c->model('ISRC')->delete( $self->data->{isrc}{id} );
}

no Moose;
__PACKAGE__->meta->make_immutable;

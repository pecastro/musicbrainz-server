package MusicBrainz::Server::Edit::Medium::AddDiscID;
use Moose;
use Method::Signatures::Simple;
use MooseX::Types::Structured qw( Dict );
use MooseX::Types::Moose qw( Int Str );
use MusicBrainz::Server::Constants qw( $EDIT_MEDIUM_ADD_DISCID );
use MusicBrainz::Server::Edit::Types qw( NullableOnPreview );
use MusicBrainz::Server::Translation qw( l ln );
use MusicBrainz::Server::Translation qw( l ln );

sub edit_name { l('Add disc ID') }
sub edit_type { $EDIT_MEDIUM_ADD_DISCID }

use aliased 'MusicBrainz::Server::Entity::CDTOC';
use aliased 'MusicBrainz::Server::Entity::MediumCDTOC';
use aliased 'MusicBrainz::Server::Entity::Release';

extends 'MusicBrainz::Server::Edit';
with 'MusicBrainz::Server::Edit::Role::Insert';
with 'MusicBrainz::Server::Edit::Medium';
with 'MusicBrainz::Server::Edit::Role::Preview';

has '+data' => (
    isa => Dict[
        cdtoc     => Str,
        medium_id => NullableOnPreview[Int],
        release   => NullableOnPreview[Dict[
            id => Int,
            name => Str
        ]],
    ]
);

method release_id { $self->data->{release}{id} }

method alter_edit_pending
{
    return {
        MediumCDTOC => [ $self->entity_id ],
    }
}

sub initialize {
    my ($self, %opts) = @_;

    if ($self->preview)
    {
       $self->entity_id(0);
    }
    else {
        my $release = $opts{release} or die 'Missing "release" argument';
        $opts{release} = {
            id => $release->id,
            name => $release->name
        };
    }

    $self->data(\%opts);
};

method related_entities
{
    return {
        release => [ $self->release_id ]
    }
}

method foreign_keys
{
    return {
        Release => { $self->release_id => [ 'ArtistCredit' ] },
        MediumCDTOC => [ $self->entity_id => [ 'CDTOC' ] ]
    }
}

method build_display_data ($loaded)
{
    return {
        release => $loaded->{Release}{ $self->release_id } ||
            Release->new(
                name => $self->data->{release}{name}
            ),
        medium_cdtoc => $loaded->{MediumCDTOC}{ $self->entity_id } ||
            MediumCDTOC->new(
                cdtoc => CDTOC->new_from_toc($self->data->{cdtoc})
            )
    }
}

override 'insert' => sub {
    my ($self) = @_;
    my $cdtoc_id = $self->c->model('CDTOC')->find_or_insert($self->data->{cdtoc});
    my $medium_cdtoc = $self->c->model('MediumCDTOC')->insert({
        medium => $self->data->{medium_id},
        cdtoc => $cdtoc_id
    });
    $self->entity_id($medium_cdtoc);
};

no Moose;
__PACKAGE__->meta->make_immutable;

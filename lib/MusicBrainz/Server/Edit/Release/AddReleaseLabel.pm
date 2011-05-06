package MusicBrainz::Server::Edit::Release::AddReleaseLabel;
use Carp;
use Moose;
use MooseX::Types::Moose qw( Int Str );
use MooseX::Types::Structured qw( Dict );
use MusicBrainz::Server::Constants qw( $EDIT_RELEASE_ADDRELEASELABEL );
use MusicBrainz::Server::Edit::Types qw( Nullable NullableOnPreview );
use MusicBrainz::Server::Translation qw( l ln );

extends 'MusicBrainz::Server::Edit';
with 'MusicBrainz::Server::Edit::Role::Preview';
with 'MusicBrainz::Server::Edit::Release';
with 'MusicBrainz::Server::Edit::Release::RelatedEntities';

sub edit_name { l('Add release label') }
sub edit_type { $EDIT_RELEASE_ADDRELEASELABEL }
sub alter_edit_pending { { Release => [ shift->release_id ] } }

use aliased 'MusicBrainz::Server::Entity::Label';
use aliased 'MusicBrainz::Server::Entity::Release';

around related_entities => sub {
    my ($orig, $self, @args) = @_;
    return {
        %{ $self->$orig(@args) },
        label => [ $self->data->{label}{id} ]
    }
};

has '+data' => (
    isa => Dict[
        release => NullableOnPreview[Dict[
            id => Int,
            name => Str
        ]],
        label => Nullable[Dict[
            id => Int,
            name => Str
        ]],
        catalog_number => Nullable[Str]
    ]
);

sub release_id { shift->data->{release}{id} }

sub initialize {
    my ($self, %opts) = @_;

    unless ($self->preview) {
        my $release = delete $opts{release} or die 'Missing "release" argument';
        $opts{release} = {
            id => $release->id,
            name => $release->name
        };
    }

    $opts{label} = {
        id => $opts{label}->id,
        name => $opts{label}->name
    } if $opts{label};

    $self->data(\%opts);
};

sub foreign_keys
{
    my $self = shift;
    my %fk = (
        Release => { $self->release_id => ['ArtistCredit'] },
    );

    if (my $lbl = $self->data->{label}) {
        $fk{Label} = [ $lbl->{id} ]
    }

    return \%fk;
};

sub build_display_data
{
    my ($self, $loaded) = @_;

    my $data = {
        catalog_number => $self->data->{catalog_number},
    };

    unless ($self->preview) {
        $data->{release} = $loaded->{Release}->{ $self->release_id }
            || Release->new( name => $self->data->{release}{name} );
    }

    if (my $lbl = $self->data->{label}) {
        $data->{label} = $loaded->{Label}->{ $lbl->{id} } ||
            Label->new( name => $lbl->{name} );
    }

    return $data;
}

sub accept
{
    my $self = shift;
    $self->c->model('ReleaseLabel')->insert({
        release_id => $self->release_id,
        label_id   => $self->data->{label}{id},
        catalog_number => $self->data->{catalog_number}
    });
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=head1 COPYRIGHT

Copyright (C) 2010 MetaBrainz Foundation

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut

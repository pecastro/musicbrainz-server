package MusicBrainz::Server::WebService::Serializer::XML::1::RecordingPUID;
use Moose;
use aliased 'MusicBrainz::Server::WebService::Serializer::XML::1::ArtistCredit';

extends 'MusicBrainz::Server::WebService::Serializer::XML::1';

use MusicBrainz::Server::WebService::Serializer::XML::1::Utils qw( list_of );

sub element { 'track'; }

before 'serialize' => sub
{
    my ($self, $entity, $inc, $opts) = @_;

    $self->attributes->{id} = $entity->recording->gid;

    $self->add( $self->gen->title($entity->recording->name) );
    $self->add( $self->gen->duration($entity->recording->length) )
        if $entity->recording->length;

    $self->add( ArtistCredit->new->serialize($entity->recording->artist_credit) )
        if $entity->recording->artist_credit;

    $self->add(
        list_of(
            $opts->{recording_release_map}{ $entity->recording->id },
            undef, { track_map => $opts->{track_map} }
        )
    );
};

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

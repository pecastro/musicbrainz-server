package MusicBrainz::Server::WebService::Serializer::XML::1::Utils;

use base 'Exporter';
use Readonly;

our @EXPORT_OK = qw(
    serializer
    serialize_entity
);

Readonly my %ENTITY_TO_SERIALIZER => (
    'MusicBrainz::Server::Entity::Artist' => 'MusicBrainz::Server::WebService::Serializer::XML::1::Artist',
    'MusicBrainz::Server::Entity::ArtistAlias' => 'MusicBrainz::Server::WebService::Serializer::XML::1::Alias',
    'MusicBrainz::Server::Entity::ArtistCredit' => 'MusicBrainz::Server::WebService::Serializer::XML::1::ArtistCredit',
    'MusicBrainz::Server::Entity::Label' => 'MusicBrainz::Server::WebService::Serializer::XML::1::Label',
    'MusicBrainz::Server::Entity::LabelAlias' => 'MusicBrainz::Server::WebService::Serializer::XML::1::Alias',
    'MusicBrainz::Server::Entity::Recording' => 'MusicBrainz::Server::WebService::Serializer::XML::1::Recording',
    'MusicBrainz::Server::Entity::Relationship' => 'MusicBrainz::Server::WebService::Serializer::XML::1::Relation',
    'MusicBrainz::Server::Entity::Release' => 'MusicBrainz::Server::WebService::Serializer::XML::1::Release',
    'MusicBrainz::Server::Entity::ReleaseGroup' => 'MusicBrainz::Server::WebService::Serializer::XML::1::ReleaseGroup',
);

sub serializer
{
    my $entity = shift;

    my $class = $ENTITY_TO_SERIALIZER{$entity->meta->name};

    Class::MOP::load_class($class);

    return $class;
}

sub serialize_entity
{
    return serializer($_[0])->new->serialize(@_);
}

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
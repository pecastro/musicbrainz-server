package MusicBrainz::Server::WebService::Serializer::XML::1::CDTOC;
use Moose;

extends 'MusicBrainz::Server::WebService::Serializer::XML::1';

sub element { 'disc' }

sub attributes
{
    my ($self, $entity, $inc, $opts) = @_;
    my @attrs;
    push @attrs, ( id => $entity->cdtoc->discid );
    push @attrs, ( sectors => $entity->cdtoc->leadout_offset );
    return @attrs;
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

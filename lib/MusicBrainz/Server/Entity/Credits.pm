package MusicBrainz::Server::Entity::Credit;

use Moose;
use MusicBrainz::Server::Entity::Types;

# has 'credits' => (
#     is => 'rw',
#     isa => 'HashRef[ArrayRef[Credit]]',
#     lazy => 1,
#     default => sub { [] },
#     traits => [ 'Array' ],
# #     handles => {
# #         all_tracks => 'elements',
# #         add_track => 'push',
# #         clear_tracks => 'clear'
# #     }
# );

# sub add_credit
# {
#     my ($self, $c) = @_;

    
# }

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=head1 NAME

MusicBrainz::Server::Entity::Credits

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

package MusicBrainz::Server::Entity::ArtistCredit;
use Moose;

use MusicBrainz::Server::Entity::Types;
use aliased 'MusicBrainz::Server::Entity::ArtistCreditName';

extends 'MusicBrainz::Server::Entity';

has 'names' => (
    is => 'rw',
    isa => 'ArrayRef[ArtistCreditName]',
    default => sub { [] },
    traits => [ 'Array' ],
    handles => {
        add_name => 'push',
        clear_names => 'clear',
        all_names => 'elements',
    }
);

has 'artist_count' => (
    is => 'rw',
    isa => 'Int'
);

sub name
{
    my ($self) = @_;
    my $result = '';
    foreach my $name (@{$self->names}) {
        $result .= $name->name;
        $result .= $name->join_phrase if $name->join_phrase;
    }
    return $result;
}

sub from_artist
{
    my ($class, $artist) = @_;
    return $class->new(
        names => [
            ArtistCreditName->new(
                artist_id => $artist->id,
                name      => $artist->name
            )
        ]
    );
}

sub from_array
{
    my ($class, @ac) = @_;

    my $ret = $class->new;

    @ac = @{ $ac[0] } if ref $ac[0];

    while (@ac)
    {
        my $artist = shift @ac;
        my $join = shift @ac;

        next unless $artist && $artist->{name};

        my %initname = ( name => $artist->{name} );

        $initname{join_phrase} = $join if $join;
        $initname{artist_id} = $artist->{artist} if $artist->{artist};

        $ret->add_name( ArtistCreditName->new(%initname) );
    }

    return $ret;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=head1 COPYRIGHT

Copyright (C) 2009 Lukas Lalinsky

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

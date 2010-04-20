package MusicBrainz::Server::Data::Credits;

use Moose;

extends 'MusicBrainz::Server::Data::Entity';

sub load
{
    my ($self, $c, @entities) = @_;

    foreach my $entity (@entities)
    {
        foreach my $rel (@{ $entity->relationships })
        {
            next unless $rel->target->isa('MusicBrainz::Server::Entity::Artist');

            foreach (@{ $rel->short_phrases })
            {
                $entity->add_credit($_, $rel->target, $rel->link->type->child_order);
            }
        }

        next unless $entity->meta->has_method('child_relationships');

        if ($entity->meta->has_method('make_combine_credit_contexts'))
        {
            $entity->make_combine_credit_contexts($c);
        }

        foreach (@{ $entity->child_relationships })
        {
            my ($rel, $context) = ($_->{relationship}, $_->{context});

            next unless $rel->target->isa('MusicBrainz::Server::Entity::Artist');

            foreach (@{ $rel->short_phrases })
            {
                $entity->add_credit($_, $rel->target,
                    $rel->link->type->child_order, $context);
            }
        }
    }
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

MusicBrainz::Server::Data::Credits

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


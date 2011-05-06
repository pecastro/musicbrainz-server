package MusicBrainz::Server::Controller::Role::Relationship;
use Moose::Role -traits => 'MooseX::MethodAttributes::Role::Meta::Role';

use MusicBrainz::Server::Data::Utils qw( model_to_type );

requires 'load';

sub relationships : Chained('load') PathPart('relationships')
{
    my ($self, $c) = @_;
    my $entity = $c->stash->{$self->{entity_name}};
    $c->model('Relationship')->load($entity);
}

sub relate : Chained('load')
{
    my ($self, $c) = @_;

    my $type   = model_to_type( $self->{model} );
    my $entity = $c->stash->{ $self->{entity_name} };

    if ($c->session->{relationship}) {
        $c->response->redirect($c->uri_for('/edit/relationship/create', {
            type0 => $c->session->{relationship}->{type0},
            type1 => $type,
            entity0 => $c->session->{relationship}->{entity0},
            entity1 => $entity->gid
        }));

        delete $c->session->{relationship};
    }
    else {
        $c->session->{relationship} = {
            type0   => $type,
            entity0 => $entity->gid,
            name    => $entity->name,
            id      => $entity->id
        };

        $c->response->redirect($c->req->referer);
    }
}

after 'load' => sub {
    my ($self, $c) = @_;
    my $entity = $c->stash->{entity};
    $c->model('Relationship')->load_subset([ 'url' ], $entity);
};

no Moose::Role;
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

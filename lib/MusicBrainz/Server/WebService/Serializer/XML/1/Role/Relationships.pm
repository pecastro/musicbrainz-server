package MusicBrainz::Server::WebService::Serializer::XML::1::Role::Relationships;
use Moose::Role;

use aliased 'MusicBrainz::Server::WebService::Serializer::XML::1::List';

requires 'serialize';

before 'serialize' => sub 
{
    my ($self, $entity, $inc, $opts) = @_;

    my %rels;
    foreach (@{$opts->{rels}})
    {
        $rels{$_->target_type} = [] unless $rels{$_->target_type};

        push @{$rels{$_->target_type}}, $_;
    }

    foreach my $key (keys %rels)
    {
        $self->add( List->new->serialize({ 'target-type' => ucfirst($key) }, $rels{$key}) );
    }
};

no Moose::Role;
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


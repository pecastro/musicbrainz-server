package MusicBrainz::Server::Edit::WikiDoc::Change;
use Moose;

use MusicBrainz::Server::Constants qw( $EDIT_WIKIDOC_CHANGE :expire_action :quality );
use MusicBrainz::Server::Edit::Types qw( Nullable );
use MusicBrainz::Server::Translation qw( l ln );
use MooseX::Types::Moose qw( Int Str );
use MooseX::Types::Structured qw( Dict );

extends 'MusicBrainz::Server::Edit';
with 'MusicBrainz::Server::Edit::WikiDoc';

sub edit_type { $EDIT_WIKIDOC_CHANGE }
sub edit_name { l("Change WikiDoc") }

sub edit_conditions
{
    my $conditions = {
        duration      => 0,
        votes         => 0,
        expire_action => $EXPIRE_ACCEPT,
        auto_edit     => 1,
    };
    return {
        $QUALITY_LOW    => $conditions,
        $QUALITY_NORMAL => $conditions,
        $QUALITY_HIGH   => $conditions,
    };
}

has '+data' => (
    isa => Dict[
        page => Str,
        old_version => Nullable[Int],
        new_version => Nullable[Int]
    ]
);

sub initialize
{
    my ($self, %opts) = @_;

    $self->data({
        page => $opts{page},
        old_version => $opts{old_version},
        new_version => $opts{new_version}
    });
}

sub accept
{
    my $self = shift;

    $self->c->model('WikiDocIndex')->set_page_version(
        $self->data->{page}, $self->data->{new_version});
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

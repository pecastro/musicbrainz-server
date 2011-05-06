package MusicBrainz::Server::Data::Tracklist;

use Moose;
use MusicBrainz::Server::Entity::Tracklist;
use MusicBrainz::Server::Data::Utils qw( load_subobjects placeholders );

extends 'MusicBrainz::Server::Data::Entity';

sub _table
{
    return 'tracklist';
}

sub _columns
{
    return 'id, track_count';
}

sub _entity_class
{
    return 'MusicBrainz::Server::Entity::Tracklist';
}

sub insert
{
    my ($self, $tracks) = @_;
    # track_count is 0 because the trigger will increment it
    my $id = $self->sql->insert_row('tracklist', { track_count => 0 }, 'id');
    $self->_add_tracks($id, $tracks);
    $self->c->model('DurationLookup')->update($id);
    my $class = $self->_entity_class;
    return $class->new( id => $id );
}

sub delete
{
    my ($self, @tracklist_ids) = @_;
    my $query = 'DELETE FROM track WHERE tracklist IN (' . placeholders(@tracklist_ids). ')';
    $self->sql->do($query, @tracklist_ids);
    $query = 'DELETE FROM tracklist WHERE id IN ('. placeholders(@tracklist_ids) . ')';
    $self->sql->do($query, @tracklist_ids);
}

sub replace
{
    my ($self, $tracklist_id, $tracks) = @_;
    $self->sql->do('DELETE FROM track WHERE tracklist = ?', $tracklist_id);
    $self->_add_tracks($tracklist_id, $tracks);
}

sub _add_tracks {
    my ($self, $id, $tracks) = @_;
    my $i = 1;
    for (@$tracks) {
        $_->{tracklist} = $id;
        $_->{position} = $i++;
    }
    $self->c->model('Track')->insert(@$tracks);
}

sub load
{
    my ($self, @objs) = @_;
    load_subobjects($self, 'tracklist', @objs);
}

sub usage_count
{
    my ($self, $tracklist_id) = @_;
    $self->sql->select_single_value(
        'SELECT count(*) FROM medium
           JOIN tracklist ON medium.tracklist = tracklist.id
          WHERE tracklist.id = ?', $tracklist_id);
}

sub garbage_collect {
    my $self = shift;

    my @orphaned_tracklists = @{
        $self->sql->select_single_column_array(
            'SELECT tracklist.id FROM tracklist
          LEFT JOIN medium ON medium.tracklist = tracklist.id
              WHERE medium.id IS NULL'
        )
    };

    if (@orphaned_tracklists) {
        $self->sql->do(
            'DELETE FROM track
              WHERE tracklist IN ('. placeholders(@orphaned_tracklists) . ')',
            @orphaned_tracklists);
        $self->sql->do(
            'DELETE FROM tracklist
              WHERE id IN ('. placeholders(@orphaned_tracklists) . ')',
            @orphaned_tracklists);
    }
}

sub set_lengths_to_cdtoc
{
    my ($self, $tracklist_id, $cdtoc_id) = @_;
    my $cdtoc = $self->c->model('CDTOC')->get_by_id($cdtoc_id)
        or die "Could not load CDTOC";

    my @info = @{ $cdtoc->track_details };
    for my $i (0..$#info) {
        my $query = 'UPDATE track SET length = ? WHERE tracklist = ? AND position = ?';
        $self->sql->do($query, $info[$i]->{length_time}, $tracklist_id, $i + 1);
    }

    $self->c->model('DurationLookup')->update($tracklist_id);
}

sub merge
{
    my ($self, $new_tracklist_id, $old_tracklist_id) = @_;
    my @recording_merges = @{
        $self->sql->select_list_of_lists(
            'SELECT newr.id AS new, oldr.id AS old
               FROM track oldt
               JOIN track newt ON newt.position = oldt.position
               JOIN recording newr ON newt.recording = newr.id
               JOIN recording oldr ON oldt.recording = oldr.id
              WHERE newt.tracklist = ? AND oldt.tracklist = ?',
            $new_tracklist_id, $old_tracklist_id
        )
    };

    for my $recording_merge (@recording_merges) {
        $self->c->model('Recording')->merge(@$recording_merge);
    }
}

sub find_or_insert
{
    my ($self, $tracks) = @_;

    my $query =
        'SELECT tracklist
           FROM (
                    SELECT tracklist FROM track
                      JOIN track_name name ON name.id = track.name
                     WHERE ' . join(' OR ', ('(
                               name.name = ?
                           AND artist_credit = ?
                           AND recording = ?
                           AND position = ?
                           )') x @$tracks) . '
                ) s
       GROUP BY tracklist
         HAVING COUNT(tracklist) = ?';

    my @possible_tracklists = @{
        $self->sql->select_single_column_array(
            $query,
            (map {
                $_->{name},
                $_->{artist_credit},
                $_->{recording_id},
                $_->{position}
            } @$tracks),
            scalar(@$tracks)
        )
    };

    if (@possible_tracklists == 1) {
        return $self->_entity_class->new(
            id => $possible_tracklists[0]
        );
    }
    else {
        $self->insert($tracks);
    }
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

package MusicBrainz::Server::Data::Vote;
use Moose;

use Moose::Util::TypeConstraints qw( find_type_constraint );
use List::Util qw( sum );
use MusicBrainz::Server::Data::Utils qw(
    map_query
    placeholders
    query_to_list
);
use MusicBrainz::Server::Email;
use MusicBrainz::Server::Types qw( $VOTE_YES $VOTE_NO $VOTE_ABSTAIN );

extends 'MusicBrainz::Server::Data::Entity';

sub _columns
{
    return 'id, editor, edit, vote_time, vote, superseded';
}

sub _table
{
    return 'vote';
}

sub _entity_class
{
    return 'MusicBrainz::Server::Entity::Vote';
}

sub _column_mapping
{
    return {
        editor_id => 'editor',
        edit_id => 'edit',
        vote => 'vote',
        vote_time => 'vote_time',
        superseded => 'superseded',
    };
}

sub enter_votes
{
    my ($self, $editor_id, @votes) = @_;
    return unless @votes;

    # Filter any invalid votes
    my $vote_tc = find_type_constraint('VoteOption');
    @votes = grep { $vote_tc->check($_->{vote}) } @votes;

    my $query;
    Sql::run_in_transaction(sub {
        $self->sql->do('LOCK vote IN SHARE ROW EXCLUSIVE MODE');

        # Filter votes on edits that are open
        my @edit_ids = map { $_->{edit_id} } @votes;
        my $edits = $self->c->model('Edit')->get_by_ids(@edit_ids);
        @votes = grep {
            my $edit = $edits->{ $_->{edit_id} };
            defined $edit && $edit->is_open
        } @votes;

        return unless @votes;

        # Also filter duplicate votes
        my $current_votes = $self->sql->select_list_of_hashes(
            'SELECT vote, edit FROM vote ' .
            'WHERE superseded = FALSE AND editor = ? AND edit IN (' .
              placeholders(@edit_ids) . ')',
            $editor_id, @edit_ids);
        my %current_votes = map { $_->{edit} => $_->{vote} } @$current_votes;

        # Filter votes where the user has either not voted before, or previously casted a different vote
        @votes = grep {
            !exists $current_votes{$_->{edit_id}} || $current_votes{$_->{edit_id}} != $_->{vote}
        } @votes;
        @edit_ids = map { $_->{edit_id} } @votes;

        return unless @votes;

        # Supersede any existing votes
        $query = 'UPDATE vote SET superseded = TRUE' .
                 ' WHERE editor = ? AND superseded = FALSE AND edit IN (' . placeholders(@edit_ids) . ')'.
                 ' RETURNING edit, vote';
        my $superseded = $self->sql->select_list_of_hashes($query, $editor_id, @edit_ids);

        my %delta;
        # Change the vote count delta for any votes that were changed
        for my $s (@$superseded) {
            my $id = $s->{edit};
            --( $delta{ $id }->{no}  ) if $s->{vote} == $VOTE_NO;
            --( $delta{ $id }->{yes} ) if $s->{vote} == $VOTE_YES;
        }

        # Select all the edits that have not yet received a no vote
        $query = 'SELECT edit FROM vote WHERE edit IN (' . placeholders(@edit_ids) . ') AND vote = ?';
        my $emailed = $self->sql->select_single_column_array($query, @edit_ids, $VOTE_NO);
        my %already_emailed = map { $_ => 1 } @$emailed;

        # Insert our new votes
        $query = 'INSERT INTO vote (editor, edit, vote) VALUES ';
        $query .= join ", ", (('(?, ?, ?)') x @votes);
        $query .= ' RETURNING edit, vote';
        my $voted = $self->sql->select_list_of_hashes($query, map { $editor_id, $_->{edit_id}, $_->{vote} } @votes);
        my %edit_to_vote = map { $_->{edit} => $_->{vote} } @$voted;
        my @email_edit_ids = grep { $edit_to_vote{$_} == $VOTE_NO }
                             grep { !exists $already_emailed{$_} } @edit_ids;

        # Change the vote count delta for any votes that were changed
        for my $s (@$voted) {
            my $id = $s->{edit};
            ++( $delta{ $id }->{no}  ) if $s->{vote} == $VOTE_NO;
            ++( $delta{ $id }->{yes} ) if $s->{vote} == $VOTE_YES;

            $query = 'UPDATE edit SET yes_votes = yes_votes + ?, no_votes = no_votes + ?' .
                     ' WHERE id = ?';
            $self->sql->do($query, $delta{ $id }->{yes} || 0, $delta{ $id }->{no} || 0, $id);
        }

        # Send out the emails for no votes
        my $email = MusicBrainz::Server::Email->new( c => $self->c );
        my $editors = $self->c->model('Editor')->get_by_ids((map { $edits->{$_}->editor_id } @email_edit_ids),
                                                            $editor_id);
        $self->c->model('Editor')->load_preferences(values %$editors);
        for my $edit_id (@email_edit_ids) {
            my $edit = $edits->{ $edit_id };
            my $voter = $editors->{ $editor_id  };
            my $editor = $editors->{ $edit->editor_id };
            $email->send_first_no_vote(edit_id => $edit_id, voter => $voter, editor => $editor )
                if $editor->preferences->email_on_no_vote;
        }
    }, $self->c->sql);
}

sub editor_statistics
{
    my ($self, $editor_id) = @_;

    my $base_query = "SELECT vote, count(vote) AS count " .
        "FROM vote " .
        "WHERE editor = ? ";

    my $q_all_votes    = $base_query . "GROUP BY vote";
    my $q_recent_votes = $base_query .
        " AND vote_time > NOW() - INTERVAL '28 day' " .
        " GROUP BY vote";

    my $all_votes = map_query($self->c->sql, 'vote' => 'count', $q_all_votes, $editor_id);
    my $recent_votes = map_query($self->c->sql, 'vote' => 'count', $q_recent_votes, $editor_id);

    my %names = (
        $VOTE_ABSTAIN => 'Abstain',
        $VOTE_NO => 'No',
        $VOTE_YES => 'Yes',
    );

    return [
        # Summarise for each vote type
        (map { +{
            name   => $names{$_},
            recent => {
                count      => $recent_votes->{$_} || 0,
                percentage => int(($recent_votes->{$_} || 0) / (sum(values %$recent_votes) || 1) * 100 + 0.5)
            },
            all   => {
                count      => ($all_votes->{$_} || 0),
                percentage => int(($all_votes->{$_} || 0) / (sum(values %$all_votes) || 1) * 100 + 0.5)
            }
        } } ( $VOTE_YES, $VOTE_NO, $VOTE_ABSTAIN )),

        # Add totals
        {
            name => 'Total',
            recent => {
                count      => sum(values %$recent_votes) || 0,
            },
            all => {
                count      => sum(values %$all_votes) || 0,
            }
        }
    ]
}

sub load_for_edits
{
    my ($self, @edits) = @_;
    my %id_to_edit = map { $_->id => $_ } @edits;
    my @ids = keys %id_to_edit;
    return unless @ids; # nothing to do
    my $query = "SELECT " . $self->_columns . "
                 FROM " . $self->_table . "
                 WHERE edit IN (" . placeholders(@ids) . ")
                 ORDER BY vote_time";
    my @votes = query_to_list($self->c->sql, sub {
            my $vote = $self->_new_from_row(@_);
            my $edit = $id_to_edit{$vote->edit_id};
            $edit->add_vote($vote);
            $vote->edit($edit);

            return $vote
        }, $query, @ids);
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;


=head1 COPYRIGHT

Copyright (C) 2009 Oliver Charles

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

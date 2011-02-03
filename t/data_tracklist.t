use strict;
use warnings;
use Test::More;
use_ok 'MusicBrainz::Server::Data::Tracklist';
use MusicBrainz::Server::Data::Track;

use MusicBrainz::Server::Context;
use MusicBrainz::Server::Test;

my $c = MusicBrainz::Server::Test->create_test_context();
MusicBrainz::Server::Test->prepare_test_database($c);
MusicBrainz::Server::Test->prepare_test_database($c, '+tracklist');

my $tracklist_data = MusicBrainz::Server::Data::Tracklist->new(c => $c);

my $tracklist1 = $tracklist_data->get_by_id(1);
is ( $tracklist1->id, 1, "id" );
is ( $tracklist1->track_count, 7, "track count");

my $tracklist2 = $tracklist_data->get_by_id(2);
is ( $tracklist2->id, 2, "id" );
is ( $tracklist2->track_count, 9, "track count" );

my $track_data = MusicBrainz::Server::Data::Track->new(c => $c);
$track_data->load_for_tracklists($tracklist1, $tracklist2);
is ( scalar($tracklist1->all_tracks), 7, "7 tracks" );
is ( $tracklist1->tracks->[0]->name, "King of the Mountain", "first track is King of the Mountain" );
is ( $tracklist1->tracks->[5]->name, "Joanni", "sixth track is Joanni" );
is ( scalar($tracklist2->all_tracks), 9, "9 tracks" );
is ( $tracklist2->tracks->[3]->name, "The Painter's Link", "fourth track is The Painter's Link" );

my $tracklist = $tracklist_data->find_or_insert([{
    name => 'Track 1',
    position => 1,
    artist_credit => 1,
    recording => 1
}, {
    name => 'Track 2',
    position => 2,
    artist_credit => 1,
    recording => 2
}]);

$tracklist = $tracklist_data->get_by_id($tracklist->id);
$track_data->load_for_tracklists($tracklist);
is($tracklist->track_count, 2, "Inserted a new tracklist with two tracks");
is($tracklist->all_tracks, 2);
is($tracklist->tracks->[0]->name, 'Track 1', "Track 1");
is($tracklist->tracks->[0]->position, 1, "... at position 1");
is($tracklist->tracks->[0]->artist_credit_id, 1, "... with artist_credit 1");
is($tracklist->tracks->[0]->recording_id, 1, "... with recording id 1");
is($tracklist->tracks->[1]->name, 'Track 2', "Track 2");
is($tracklist->tracks->[1]->position, 2, "... at position 2");
is($tracklist->tracks->[1]->artist_credit_id, 1, "... with artist credit 1");
is($tracklist->tracks->[1]->recording_id, 2, "... with recording id 2");

subtest 'Can set tracklist times via a disc id' => sub {
    my $sql = Sql->new($c->dbh);
    Sql::run_in_transaction(sub {
        $tracklist_data->set_lengths_to_cdtoc(1, 1);
    }, $sql);

    $tracklist = $tracklist_data->get_by_id(1);
    $track_data->load_for_tracklists($tracklist);
    is($tracklist->tracks->[0]->length, 338000);
    is($tracklist->tracks->[1]->length, 273000);
    is($tracklist->tracks->[2]->length, 327000);
    is($tracklist->tracks->[3]->length, 252000);
    is($tracklist->tracks->[4]->length, 719000);
    is($tracklist->tracks->[5]->length, 276000);
    is($tracklist->tracks->[6]->length, 94000);
};

my $tracks = [
    { name => 'Track 1', artist_credit => 1, recording => 1 },
    { name => 'Track 2', artist_credit => 1, recording => 2 },
    { name => 'Track 3', artist_credit => 1, recording => 3 }
];

$tracklist = $tracklist_data->find_or_insert($tracks);
ok($tracklist, 'returned a tracklist id');
ok($tracklist->id > 0, 'returned a tracklist id');
is($tracklist_data->find_or_insert($tracks)->id => $tracklist->id,
   'returns the same tracklist for a reinsert');

done_testing;
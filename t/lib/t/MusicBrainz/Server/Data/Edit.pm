package t::MusicBrainz::Server::Data::Edit;
use Test::Routine;
use Test::Moose;
use Test::More;
use Test::Fatal;

BEGIN { use_ok 'MusicBrainz::Server::Data::Edit' };

{
    package t::Edit::MockEdit;
    use Moose;
    extends 'MusicBrainz::Server::Edit';
    sub edit_type { 123 }
    sub edit_name { 'mock edit' }
}

use Sql;
use MusicBrainz::Server::Context;
use MusicBrainz::Server::Test;
use MusicBrainz::Server::Types qw( :edit_status $VOTE_YES );

use MusicBrainz::Server::EditRegistry;
MusicBrainz::Server::EditRegistry->register_type("t::Edit::MockEdit");

with 't::Context';

# Test approving edits, while something (editqueue) is holding a lock on it
# Acquire an exclusive lock on the edit
test 'Test locks on edits' => sub {
    my $test = shift;
    MusicBrainz::Server::Test->prepare_test_database($test->c, '+editor');
    MusicBrainz::Server::Test->prepare_raw_test_database($test->c, '+edit');
    my $edit_data = MusicBrainz::Server::Data::Edit->new(c => $test->c);

    my $foreign_connection = MusicBrainz::Server::DatabaseConnectionFactory->get_connection(
        'RAWDATA',
        fresh => 1
    );

    # We have to have some data present outside transactions.
    $foreign_connection->dbh->do(
        q{INSERT INTO edit (id, editor, type, status, data, expire_time)
             VALUES (12345, 1, 123, 1, '{ "key": "value" }', NOW())}
         );

    my $sql2 = Sql->new($foreign_connection->dbh);
    $sql2->begin;
    $sql2->select_single_row_array('SELECT * FROM edit WHERE id = 12345 FOR UPDATE');

    my $edit = $edit_data->get_by_id(12345);
    like exception { $edit_data->approve($edit, 1) }, qr/could not obtain lock/;

    # Release the lock
    $sql2->rollback;
    $foreign_connection->dbh->do('DELETE FROM edit WHERE id = 12345');
};

test all => sub {

my $test = shift;
MusicBrainz::Server::Test->prepare_test_database($test->c, '+editor');
MusicBrainz::Server::Test->prepare_raw_test_database($test->c, '+edit');
my $edit_data = MusicBrainz::Server::Data::Edit->new(c => $test->c);

my $sql = $test->c->sql;
my $raw_sql = $test->c->raw_sql;

# Find all edits
my ($edits, $hits) = $edit_data->find({}, 10, 0);
is($hits, 5);
is(scalar @$edits, 5, "Found all edits");

# Check we get the edits in descending ID order
is($edits->[$_]->id, 5 - $_) for (0..4);

# Find edits with a certain status
($edits, $hits) = $edit_data->find({ status => $STATUS_OPEN }, 10, 0);
is($hits, 3);
is(scalar @$edits, 3, "Found all open edits");
is($edits->[0]->id, 5);
is($edits->[1]->id, 3);
is($edits->[2]->id, 1);

# Find edits by a specific editor
($edits, $hits) = $edit_data->find({ editor => 1 }, 10, 0);
is($hits, 2);
is(scalar @$edits, 2, "Found edits by a specific editor");
is($edits->[0]->id, 3);
is($edits->[1]->id, 1);

# Find edits by a specific editor with a certain status
($edits, $hits) = $edit_data->find({ editor => 1, status => $STATUS_OPEN }, 10, 0);
is($hits, 2);
is(scalar @$edits, 2, "Found all open edits by a specific editor");
is($edits->[0]->id, 3);
is($edits->[1]->id, 1);

# Find edits with 0 results
($edits, $hits) = $edit_data->find({ editor => 122 }, 10, 0);
is($hits, 0);
is(scalar @$edits, 0, "Found no edits for a specific editor");

# Find edits by a certain artist
($edits, $hits) = $edit_data->find({ artist => 1 }, 10, 0);
is($hits, 2);
is(scalar @$edits, 2, "Found edits by a certain artist");
is($edits->[0]->id, 4);
is($edits->[1]->id, 1);

($edits, $hits) = $edit_data->find({ artist => 1, status => $STATUS_APPLIED }, 10, 0);
is($hits, 1);
is(scalar @$edits, 1, "Found applied edits by a certain artist");
is($edits->[0]->id, 4);

# Find edits over multiple entities
($edits, $hits) = $edit_data->find({ artist => [1,2] }, 10, 0);
is($hits, 1);
is(scalar @$edits, 1, "Found edits over multiple entities");
is($edits->[0]->id, 4);

# Test accepting edits
my $edit = $edit_data->get_by_id(1);

my $editor = $test->c->model('Editor')->get_by_id($edit->editor_id);
is($editor->accepted_edits, 12, "Edit not yet accepted");

$sql->begin;
$raw_sql->begin;
$edit_data->accept($edit);
$sql->commit;
$raw_sql->commit;

$editor = $test->c->model('Editor')->get_by_id($edit->editor_id);
is($editor->accepted_edits, 13, "Edit accepted");

# Test rejecting edits
$edit = $edit_data->get_by_id(3);

$editor = $test->c->model('Editor')->get_by_id($edit->editor_id);
is($editor->rejected_edits, 2, "Edit not yet rejected");

$sql->begin;
$raw_sql->begin;
$edit_data->reject($edit, $STATUS_FAILEDVOTE);
$sql->commit;
$raw_sql->commit;

$editor = $test->c->model('Editor')->get_by_id($edit->editor_id);
is($editor->rejected_edits, 3, "Edit rejected");

# Test approving edits, successfully this time
$edit = $edit_data->get_by_id(5);
$edit_data->approve($edit, 1);

$edit = $edit_data->get_by_id(5);
is($edit->status, $STATUS_APPLIED);

$test->c->model('Vote')->load_for_edits($edit);
is($edit->votes->[0]->vote, $VOTE_YES);
is($edit->votes->[0]->editor_id, 1);

# Test canceling

$edit = $edit_data->get_by_id(2);
$edit_data->cancel($edit);

$edit = $edit_data->get_by_id(2);
is($edit->status, $STATUS_TOBEDELETED);

# Test deleting

$sql->begin;
$raw_sql->begin;
$edit_data->reject($edit, $STATUS_DELETED);
$sql->commit;
$raw_sql->commit;

$edit = $edit_data->get_by_id(2);
is($edit->status, $STATUS_DELETED);

subtest 'Find edits by subscription' => sub {
    use aliased 'MusicBrainz::Server::Entity::ArtistSubscription';
    use aliased 'MusicBrainz::Server::Entity::LabelSubscription';
    use aliased 'MusicBrainz::Server::Entity::EditorSubscription';

    my $sub = ArtistSubscription->new( artist_id => 1, last_edit_sent => 0 );
    my @edits = $edit_data->find_for_subscription($sub);
    is(@edits => 2, 'found 2 edits');
    ok((grep { $_->id == 1 } @edits), 'has edit #1');
    ok((grep { $_->id == 4 } @edits), 'has edit #4');

    $sub = ArtistSubscription->new( artist_id => 1, last_edit_sent => 1 );
    @edits = $edit_data->find_for_subscription($sub);
    is(@edits => 1, 'found 1 edits');
    ok(!(grep { $_->id == 1 } @edits), 'does not have edit #1');
    ok((grep { $_->id == 4 } @edits), 'has edit #4');

    $sub = EditorSubscription->new( subscribed_editor_id => 2, last_edit_sent => 0 );
    @edits = $edit_data->find_for_subscription($sub);
    is(@edits => 2, 'found 1 edits');
    ok((grep { $_->id == 2 } @edits), 'has edit #2');
    ok((grep { $_->id == 4 } @edits), 'has edit #4');

    my $sub = LabelSubscription->new( label_id => 1, last_edit_sent => 0 );
    my @edits = $edit_data->find_for_subscription($sub);
    is(@edits => 1, 'found 1 edits');
    ok((grep { $_->id == 2 } @edits), 'has edit #2');
};

};

1;
package t::MusicBrainz::Server::Edit::Artist::Delete;
use Test::Routine;
use Test::More;

with 't::Context';

BEGIN { use MusicBrainz::Server::Edit::Artist::Delete }

use MusicBrainz::Server::Constants qw( $EDIT_ARTIST_DELETE );
use MusicBrainz::Server::Types ':edit_status';
use MusicBrainz::Server::Test qw( accept_edit reject_edit );

test all => sub {

my $test = shift;
my $c = $test->c;

MusicBrainz::Server::Test->prepare_test_database($c, '+edit_artist_delete');
MusicBrainz::Server::Test->prepare_test_database($c, <<'EOSQL');
INSERT INTO editor (id, name, password) VALUES (1, 'editor', 'pass');
INSERT INTO editor (id, name, password) VALUES (4, 'modbot', 'pass');
EOSQL

my $artist = $c->model('Artist')->get_by_id(1);

my $edit = _create_edit($c, $artist);
isa_ok($edit, 'MusicBrainz::Server::Edit::Artist::Delete');

my ($edits, $hits) = $c->model('Edit')->find({ artist => 1 }, 10, 0);
is($hits, 1);
is($edits->[0]->id, $edit->id);

$artist = $c->model('Artist')->get_by_id(1);
is($artist->edits_pending, 1);

# Test rejecting the edit
reject_edit($c, $edit);
$artist = $c->model('Artist')->get_by_id(1);
ok(defined $artist);
is($artist->edits_pending, 0);

# Test accepting the edit
# This should fail as the artist has a recording linked
$edit = _create_edit($c, $artist);
accept_edit($c, $edit);
$artist = $c->model('Artist')->get_by_id(1);
is($edit->status, $STATUS_FAILEDDEP);
ok(defined $artist);

# Delete the recording and enter the edit
my $sql = $c->sql;
my $sql_raw = $c->raw_sql;
Sql::run_in_transaction(
    sub {
        $c->model('Recording')->delete(1);
    }, $sql, $sql_raw);

$edit = _create_edit($c, $artist);
accept_edit($c, $edit);
$artist = $c->model('Artist')->get_by_id(1);
ok(!defined $artist);

};

sub _create_edit {
    my ($c, $artist) = @_;
    return $c->model('Edit')->create(
        edit_type => $EDIT_ARTIST_DELETE,
        to_delete => $artist,
        editor_id => 1
    );
}

1;

package t::MusicBrainz::Server::Controller::Label::EditAlias;
use Test::Routine;
use Test::More;
use MusicBrainz::Server::Test qw( html_ok );

with 't::Mechanize', 't::Context';

test all => sub {

my $test = shift;
my $mech = $test->mech;
my $c    = $test->c;

MusicBrainz::Server::Test->prepare_test_database($c);

$mech->get_ok('/login');
$mech->submit_form( with_fields => { username => 'new_editor', password => 'password' } );

# Test deleting aliases
$mech->get_ok('/label/46f0f4cd-8aab-4b33-b698-f459faf64190/alias/1/edit');
my $response = $mech->submit_form(
    with_fields => {
        'edit-alias.name' => 'Edited alias'
    });

my $edit = MusicBrainz::Server::Test->get_latest_edit($c);
isa_ok($edit, 'MusicBrainz::Server::Edit::Label::EditAlias');
is_deeply($edit->data, {
    entity => {
        id => 2,
        name => 'Warp Records'
    },
    alias_id  => 1,
    new => {
        name => 'Edited alias',
    },
    old => {
        name => 'Test Label Alias',
    }
});

$mech->get_ok('/edit/' . $edit->id, 'Fetch edit page');
html_ok($mech->content, '..valid xml');
$mech->text_contains('Warp Records', '..has label name');
$mech->text_contains('Test Label Alias', '..has old alias name');
$mech->text_contains('Edited alias', '..has new alias name');

};

1;

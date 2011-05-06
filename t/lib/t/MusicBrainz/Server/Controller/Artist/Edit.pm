package t::MusicBrainz::Server::Controller::Artist::Edit;
use Test::Routine;
use Test::More;
use MusicBrainz::Server::Test qw( html_ok );

with 't::Mechanize', 't::Context';

use aliased 'MusicBrainz::Server::Entity::PartialDate';

test all => sub {

my $test = shift;
my $mech = $test->mech;
my $c    = $test->c;

MusicBrainz::Server::Test->prepare_test_database($c, '+controller_artist');

# Test editing artists
$mech->get_ok('/login');
$mech->submit_form( with_fields => { username => 'new_editor', password => 'password' } );

$mech->get_ok('/artist/745c079d-374e-4436-9448-da92dedef3ce/edit');
html_ok($mech->content);
my $response = $mech->submit_form(
    with_fields => {
        'edit-artist.name' => 'edit artist',
        'edit-artist.sort_name' => 'artist, controller',
        'edit-artist.type_id' => '',
        'edit-artist.country_id' => 2,
        'edit-artist.gender_id' => 2,
        'edit-artist.begin_date.year' => 1990,
        'edit-artist.begin_date.month' => 01,
        'edit-artist.begin_date.day' => 02,
        'edit-artist.end_date.year' => '',
        'edit-artist.end_date.month' => '',
        'edit-artist.end_date.day' => '',
        'edit-artist.comment' => 'artist created in controller_artist.t',
    }
);
ok($mech->success);
ok($mech->uri =~ qr{/artist/745c079d-374e-4436-9448-da92dedef3ce}, 'should redirect to artist page via gid');

my $edit = MusicBrainz::Server::Test->get_latest_edit($c);
isa_ok($edit, 'MusicBrainz::Server::Edit::Artist::Edit');
is_deeply($edit->data, {
        entity => {
            id => 3,
            name => 'Test Artist'
        },
        new => {
            name => 'edit artist',
            sort_name => 'artist, controller',
            type_id => undef,
            country_id => 2,
            gender_id => 2,
            comment => 'artist created in controller_artist.t',
            begin_date => {
                year => 1990,
                month => 01,
                day => 02
            },
            end_date => {
                year => undef,
                month => undef,
                day => undef,
            },
        },
        old => {
            name => 'Test Artist',
            sort_name => 'Artist, Test',
            type_id => 1,
            gender_id => 1,
            country_id => 1,
            comment => 'Yet Another Test Artist',
            begin_date => {
                year => 2008,
                month => 1,
                day => 2
            },
            end_date => {
                year => 2009,
                month => 3,
                day => 4
            },
        }
    });


# Test display of edit data
$mech->get_ok('/edit/' . $edit->id, 'Fetch the edit page');
html_ok ($mech->content, '..xml is valid');
$mech->content_contains ('edit artist', '.. contains old artist name');
$mech->content_contains ('Test Artist', '.. contains new artist name');
$mech->content_contains ('artist, controller', '.. contains old sort name');
$mech->content_contains ('Artist, Test', '.. contains new sort name');
$mech->content_contains ('Person', '.. contains new artist type');
$mech->content_contains ('United States', '.. contains old country');
$mech->content_contains ('United Kingdom', '.. contains new country');
$mech->content_contains ('Male', '.. contains old artist gender');
$mech->content_contains ('Female', '.. contains new artist gender');
$mech->content_contains ('2008-01-02', '.. contains old begin date');
$mech->content_contains ('1990-01-02', '.. contains new begin date');
$mech->content_contains ('2009-03-04', '.. contains old end date');
$mech->content_contains ('Yet Another Test Artist',
                         '.. contains old artist comment');
$mech->content_contains ('artist created in controller_artist.t',
                         '.. contains new artist comment');

};

1;

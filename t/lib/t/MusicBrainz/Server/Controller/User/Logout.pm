package t::MusicBrainz::Server::Controller::User::Logout;
use Test::Routine;
use Test::More;
use MusicBrainz::Server::Test qw( html_ok );

with 't::Mechanize', 't::Context';

test all => sub {

my $test = shift;
my $mech = $test->mech;
my $c    = $test->c;

MusicBrainz::Server::Test->prepare_test_database($c, '+editor');

$mech->get_ok('/login');
$mech->submit_form( with_fields => { username => 'new_editor', password => 'password' } );

$mech->get('/');
$mech->get_ok('/logout');
html_ok($mech->content);
is($mech->uri->path, '/', 'Redirected to the previous URL');
$mech->get_ok('/artist/create');
html_ok($mech->content);
$mech->content_contains('You need to be logged in to view this page');
$mech->get('/login');
$mech->get_ok('/logout');
html_ok($mech->content);
is($mech->uri->path, '/login', 'Redirected to the previous URL');
$mech->content_contains('Log In');

};

1;

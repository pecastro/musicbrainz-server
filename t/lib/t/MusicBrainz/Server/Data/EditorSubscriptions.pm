package t::MusicBrainz::Server::Data::EditorSubscriptions;
use Test::Routine;
use Test::Moose;
use Test::More;
use Test::Memory::Cycle;

use MusicBrainz::Server::Context;
use MusicBrainz::Server::Test;

BEGIN { use MusicBrainz::Server::Data::EditorSubscriptions; }

use aliased 'MusicBrainz::Server::Entity::EditorSubscription';

with 't::Context';

test all => sub {

my $test = shift;

MusicBrainz::Server::Test->prepare_test_database($test->c, '+editor');

subtest 'get_all_subscriptions' => sub {
    my @subscriptions = $test->c->model('EditorSubscriptions')
        ->get_all_subscriptions(2);
    is(@subscriptions => 1, 'found one subscription');
    isa_ok($subscriptions[0] => EditorSubscription,
        'found editor subscription');
    is($subscriptions[0]->subscribed_editor_id => 1,
        'subscribed to editor 1');

    memory_cycle_ok($test->c->model('EditorSubscriptions'));
    memory_cycle_ok(\@subscriptions);
};

subtest 'update_subscriptions' => sub {
    my @subscriptions = $test->c->model('EditorSubscriptions')
        ->get_all_subscriptions(2);
    is($subscriptions[0]->last_edit_sent, 3);

    $test->c->model('EditorSubscriptions')->update_subscriptions(4,
        $subscriptions[0]->editor_id);

    @subscriptions = $test->c->model('EditorSubscriptions')
        ->get_all_subscriptions(2);
    is($subscriptions[0]->last_edit_sent, 4);

    memory_cycle_ok($test->c->model('EditorSubscriptions'));
    memory_cycle_ok(\@subscriptions);
};

};

1;

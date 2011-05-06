package t::MusicBrainz::Server::Data::WatchArtist;
use Test::Routine;
use Test::Moose;
use Test::More;
use Test::Fatal;
use Test::Memory::Cycle;

use MusicBrainz::Server::Test;

around 'run_test' => sub {
    my $orig = shift;
    my $self = shift;

    MusicBrainz::Server::Test->prepare_test_database($self->c, '+watch');
    $self->$orig(@_);
    memory_cycle_ok($self->c->model('WatchArtist'));
};

with 't::Context' => {
    initial_sql => '+watch'
};

around '_build_context' => sub {
    my $orig = shift;
    my $self = shift;
    my $c = $self->$orig;
    return $c;
};

has sql => (
    is => 'ro',
    lazy => 1,
    default => sub {
        shift->c->sql
    }
);

test 'Find watched artists for editors watching artists' => sub {
    my $test = shift;

    my @watching = $test->c->model('WatchArtist')->find_watched_artists(1);
    is(@watching => 2, 'watching 2 artists');
    is_watching('Spor', 1, @watching);
    is_watching('Break', 2, @watching);

    memory_cycle_ok(\@watching);
};

test 'Find watched artists where an editor is not watching anyone' => sub {
    my $test = shift;

    my @watching = $test->c->model('WatchArtist')->find_watched_artists(2);
    is(@watching => 0, 'Editor #2 is not watching any artists');
};

test 'Can add new artists to the watch list' => sub {
    my $test = shift;

    $test->c->model('WatchArtist')->watch_artist(
        artist_id => 3, editor_id => 2
    );

    my @watching = $test->c->model('WatchArtist')->find_watched_artists(2);
    is(@watching => 1, 'Editor #2 is now watching 1 artist');
    is_watching('Tosca', 3, @watching);
    memory_cycle_ok(\@watching);
};

test 'Watching a watched artist does not crash' => sub {
    my $test = shift;

    ok !exception {
        $test->c->model('WatchArtist')->watch_artist(
            artist_id => 3, editor_id => 2
        );
    }, 'editor #2 watched artist #3 without an exception';
};

test 'WatchArtist->is_watching' => sub {
    my $test = shift;

    ok($test->c->model('WatchArtist')->is_watching(
        artist_id => 1, editor_id => 1),
        'editor #1 is watching artist #1');
    ok(!$test->c->model('WatchArtist')->is_watching(
        artist_id => 3, editor_id => 1),
        'editor #1 is not watching artist #3');
};

test 'WatchArtist->stop_watching' => sub {
    my $test = shift;

    $test->c->model('WatchArtist')->stop_watching_artist(
        artist_ids => [ 3 ], editor_id => 2
    );

    ok(!$test->c->model('WatchArtist')->is_watching(
        artist_id => 3, editor_id => 2),
        'editor #2 is no longer watching artist #3');
};

test 'WatchArtist->find_new_releases' => sub {
    my $test = shift;

    subtest 'Find releases in the future' => sub {
        $test->sql->begin;
        $test->sql->do('UPDATE editor_watch_preferences SET last_checked = NOW()');
        $test->sql->do("UPDATE release_meta SET date_added = NOW() + '@ 1 week'::INTERVAL");

        my @releases = $test->c->model('WatchArtist')->find_new_releases(1);
        is(@releases => 1, 'found one release');
        memory_cycle_ok(\@releases);
        $test->sql->rollback;
    };

    subtest 'Find releases after last_checked' => sub {
        $test->sql->begin;
        $test->sql->do("UPDATE release_meta SET date_added = NOW() - '@ 1 week'::INTERVAL");

        my @releases = $test->c->model('WatchArtist')->find_new_releases(1);
        is(@releases => 0, 'found no releases');
        $test->sql->rollback;
    };

    subtest 'Do not notify of newly added releases released in the past' => sub {
        $test->sql->begin;
        $test->sql->do('UPDATE release SET date_year = 2009');
        $test->sql->do("UPDATE release_meta SET date_added = NOW() + '@ 1 week'::INTERVAL");
        my @releases = $test->c->model('WatchArtist')->find_new_releases(1);
        is(@releases => 0, 'found no releases');
        $test->sql->rollback;
    };
};

test 'WatchArtist->find_editors_to_notify' => sub {
    my $test = shift;

    my @editors = $test->c->model('WatchArtist')->find_editors_to_notify;
    is(@editors => 1, '1 editors have watch lists');
    ok((grep { $_->name eq 'acid2' } @editors), 'acid2 has a watchlist');
    memory_cycle_ok(\@editors);
};

test 'WatchArtist->find_editors_to_notify ignores editors not requesting emails' => sub {
    my $test = shift;

    $test->sql->auto_commit(1);
    $test->sql->do('UPDATE editor_watch_preferences SET notify_via_email = FALSE
               WHERE editor = 1');

    my @editors = $test->c->model('WatchArtist')->find_editors_to_notify;
    is(@editors => 0, '0 editors to notify');
};

test 'WatchArtist->update_last_checked' => sub {
    my $test = shift;

    $test->sql->auto_commit(1);
    $test->sql->do("UPDATE editor_watch_preferences
                 SET last_checked = NOW() - '@ 1 week'::INTERVAL");

    $test->c->model('WatchArtist')->update_last_checked;

    ok($test->sql->select_single_value(
            "SELECT 1 FROM editor_watch_preferences
              WHERE last_checked > NOW() - '@ 1 week'::INTERVAL"),
        'last_checked has moved forward in time');
};

test 'Default preferences' => sub {
    my $test = shift;
    my $prefs = $test->c->model('WatchArtist')->load_preferences(2);
    memory_cycle_ok($prefs);

    is($prefs->notification_timeframe->in_units('days') => 7,
        'default notification timeframe is 7 days');
    is($prefs->notify_via_email => 1,
        'will notify via email by default');

    is($prefs->all_types => 1, 'will watch for albums by default');
    ok((grep { $_->id => 2 } $prefs->all_types),
        'will watch for albums by default');

    is($prefs->all_statuses => 1,
        'will watch for official releases by default');
    ok((grep { $_->id => 1 } $prefs->all_statuses),
        'will watch for official releases by default');
};

test 'Saving preferences' => sub {
    my $test = shift;
    $test->c->model('WatchArtist')->save_preferences(
        2, {
            notification_timeframe => 14,
            notify_via_email => 0,
            type_id => [ 1, 2 ],
            status_id => [ 3 ]
        });

    my $prefs = $test->c->model('WatchArtist')->load_preferences(2);
    memory_cycle_ok($prefs);

    is($prefs->notification_timeframe->in_units('days') => 14,
        'notification timeframe is 14 days');
    is($prefs->notify_via_email => 0,
        'will not notify via email');

    is($prefs->all_types => 2);
    ok((grep { $_->id => 1 } $prefs->all_types));
    ok((grep { $_->id => 2 } $prefs->all_types));

    is($prefs->all_statuses => 1);
    ok((grep { $_->id => 3 } $prefs->all_statuses));
};

sub is_watching {
    my ($name, $artist_id, @watching) = @_;
    subtest "Is watching $name" => sub {
        ok((grep { $_->name eq $name } @watching),
            '...artist.name');
        ok((grep { $_->id == $artist_id } @watching),
            '...artist_id');
    };
}

1;

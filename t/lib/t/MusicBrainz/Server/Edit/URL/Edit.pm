package t::MusicBrainz::Server::Edit::URL::Edit;
use Test::Routine;
use Test::More;
use Test::Fatal;

around run_test => sub {
    my ($orig, $test) = splice(@_, 0, 2);
    MusicBrainz::Server::Test->prepare_test_database($test->c, '+url');
    $test->_clear_edit;
    $test->edit;
    $test->$orig(@_);
};

with 't::Edit';
with 't::Context';

use MusicBrainz::Server::Context;
use MusicBrainz::Server::Constants qw( $EDIT_URL_EDIT );
use MusicBrainz::Server::Types qw( $STATUS_APPLIED );
use MusicBrainz::Server::Test qw( accept_edit reject_edit );

has edit => (
    is => 'ro',
    lazy => 1,
    clearer => '_clear_edit',
    builder => '_build_edit'
);

test 'Entering makes no changes' => sub {
    my $test = shift;
    my $url = $test->c->model('URL')->get_by_id(2);
    is($url->url, 'http://microsoft.com');
    is($url->description, 'EVIL');
    is($url->edits_pending, 1);
};

test 'Can accept' => sub {
    my $test = shift;
    accept_edit($test->c, $test->edit);
    is($test->edit->status, $STATUS_APPLIED);

    my $url = $test->c->model('URL')->get_by_id(2);
    is($url->url, 'http://apple.com');
    is($url->description, 'Possibly even more evil');
    is($url->edits_pending, 0);
};

test 'Can reject' => sub {
    my $test = shift;
    reject_edit($test->c, $test->edit);

    my $url = $test->c->model('URL')->get_by_id(2);
    is($url->url, 'http://microsoft.com');
    is($url->description, 'EVIL');
    is($url->edits_pending, 0);
};

test 'Entering the same edit twice is OK' => sub {
    my $test = shift;
    my $original_edit = $test->edit;

    my $second_edit = $test->_build_edit;
    accept_edit($test->c, $second_edit);

    accept_edit($test->c, $test->edit);
    is($test->edit->status, $STATUS_APPLIED);

    my $url = $test->c->model('URL')->get_by_id(2);
    is($url->url, 'http://apple.com');
    is($url->description, 'Possibly even more evil');
    is($url->edits_pending, 0);
};

test 'Editing a URL that no longer exists fails' => sub {
    my $test = shift;

    my $edit_1 = _build_edit($test, 'http://musicbrainz.org/');
    my $edit_2 = _build_edit($test, 'http://musicbrainz.org/');

    accept_edit($test->c, $edit_1);

    isa_ok exception { $edit_2->accept },
        'MusicBrainz::Server::Edit::Exceptions::FailedDependency';
};

test 'Can edit 2 URLs into a common URL' => sub {
    my $test = shift;

    my $builder = sub {
        my ($url_to_edit) = @_;
        $test->c->model('Edit')->create(
            edit_type => $EDIT_URL_EDIT,
            editor_id => 1,
            privileges => 1,
            to_edit => $test->c->model('URL')->get_by_id($url_to_edit),
            url => 'http://musicbrainz.org'
        );
    };

    my $edit_1 = $builder->(2);
    my $edit_2 = $builder->(3);

    is $edit_1->status, $STATUS_APPLIED;
    is $edit_2->status, $STATUS_APPLIED;
};

sub _build_edit {
    my ($test, $url, $url_to_edit) = @_;
    $test->c->model('Edit')->create(
        edit_type => $EDIT_URL_EDIT,
        editor_id => 1,
        to_edit => $test->c->model('URL')->get_by_id($url_to_edit || 2),
        url => $url || 'http://apple.com',
        description => 'Possibly even more evil'
    );
}

1;

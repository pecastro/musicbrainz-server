package t::MusicBrainz::Server::Data::EditNote;
use Test::Routine;
use Test::Moose;
use Test::More;
use Test::Exception;
use Test::Memory::Cycle;

BEGIN { use MusicBrainz::Server::Data::Gender };

use MusicBrainz::Server::Context;
use MusicBrainz::Server::Data::Edit;
use MusicBrainz::Server::Data::EditNote;
use MusicBrainz::Server::Email;
use MusicBrainz::Server::Test;

BEGIN {
    package MockEdit;
    use Moose;
    extends 'MusicBrainz::Server::Edit';

    sub edit_type { 111; }
    sub edit_name { 'mock edit' }
};

BEGIN {
    no warnings 'redefine';
    use DBDefs;
    *DBDefs::_RUNNING_TESTS = sub { 1 };
    *DBDefs::WEB_SERVER = sub { "localhost" };
}

with 't::Context';

test all => sub {

my $raw_sql = <<'RAWSQL';
SET client_min_messages TO 'WARNING';
TRUNCATE edit CASCADE;
TRUNCATE edit_note CASCADE;

-- Test multiple edit_notes
INSERT INTO edit (id, editor, type, status, data, expire_time)
    VALUES (1, 1, 111, 1, '{ "foo": "5" }', NOW());

-- Test a single note
INSERT INTO edit (id, editor, type, status, data, expire_time)
    VALUES (2, 1, 111, 1, '{ "foo": "5" }', NOW());

-- Test no edit_notes
INSERT INTO edit (id, editor, type, status, data, expire_time)
    VALUES (3, 1, 111, 1, '{ "foo": "5" }', NOW());

INSERT INTO edit_note (id, editor, edit, text)
    VALUES (1, 1, 1, 'This is a note');

INSERT INTO edit_note (id, editor, edit, text)
    VALUES (2, 2, 1, 'This is a later note');

INSERT INTO edit_note (id, editor, edit, text)
    VALUES (3, 1, 2, 'Another edit note');

ALTER SEQUENCE edit_note_id_seq RESTART 4;

RAWSQL

my $test = shift;
MusicBrainz::Server::Test->prepare_test_database($test->c, '+edit_note');
MusicBrainz::Server::Test->prepare_raw_test_database($test->c, $raw_sql);

use MusicBrainz::Server::EditRegistry;
MusicBrainz::Server::EditRegistry->register_type("MockEdit");

my $edit_data = MusicBrainz::Server::Data::Edit->new(c => $test->c);
my $en_data = MusicBrainz::Server::Data::EditNote->new(c => $test->c);

memory_cycle_ok($en_data);

# Multiple edit edit_notes
my $edit = $edit_data->get_by_id(1);
$en_data->load_for_edits($edit);
is(@{ $edit->edit_notes }, 2);
check_note($edit->edit_notes->[0], 'MusicBrainz::Server::Entity::EditNote',
       editor_id => 1,
       edit_id => 1,
       text => 'This is a note');

check_note($edit->edit_notes->[1], 'MusicBrainz::Server::Entity::EditNote',
       editor_id => 2,
       edit_id => 1,
       text => 'This is a later note');

memory_cycle_ok($en_data);
memory_cycle_ok($edit);

# Single edit note
$edit = $edit_data->get_by_id(2);
$en_data->load_for_edits($edit);
is(@{ $edit->edit_notes }, 1);
check_note($edit->edit_notes->[0], 'MusicBrainz::Server::Entity::EditNote',
       editor_id => 1,
       edit_id => 2,
       text => 'Another edit note');

# No edit edit_notes
$edit = $edit_data->get_by_id(3);
$en_data->load_for_edits($edit);
is(@{ $edit->edit_notes }, 0);

# Insert a new edit note
$en_data->insert($edit->id, {
        editor_id => 3,
        text => 'This is a new edit note',
    });

memory_cycle_ok($en_data);

$en_data->load_for_edits($edit);
is(@{ $edit->edit_notes }, 1);
check_note($edit->edit_notes->[0], 'MusicBrainz::Server::Entity::EditNote',
        editor_id => 3,
        edit_id => 3,
        text => 'This is a new edit note');

# Make sure we can insert edit notes while already in a transaction
$test->c->sql->begin;
lives_ok {
    $en_data->insert($edit->id, {
            editor_id => 3,
            text => 'Note' })
};
$test->c->sql->commit;

# Test adding edit notes with email sending
$test->c->model('Vote')->enter_votes(2, { edit_id => $edit->id, vote => 1 });

$en_data->add_note($edit->id, { text => "This is my note!", editor_id => 3 });

my $email_transport = MusicBrainz::Server::Email->get_test_transport;
is(scalar @{ $email_transport->deliveries }, 2);

my $email = $email_transport->deliveries->[1]->{email};
is($email->get_header('Subject'), 'Note added to your edit #' . $edit->id);
is($email->get_header('To'), '"editor1" <editor1@example.com>');
like($email->get_body, qr{http://localhost/edit/${\ $edit->id }});
like($email->get_body, qr{'editor3' has added});
like($email->get_body, qr{to your edit #${\ $edit->id }});
like($email->get_body, qr{This is my note!});

my $email2 = $email_transport->deliveries->[0]->{email};
is($email2->get_header('Subject'), 'Note added to edit #' . $edit->id);
is($email2->get_header('To'), '"editor2" <editor2@example.com>');
like($email2->get_body, qr{http://localhost/edit/${\ $edit->id }});
like($email2->get_body, qr{'editor3' has added});
like($email2->get_body, qr{to edit #${\ $edit->id }});
like($email2->get_body, qr{This is my note!});

};

sub check_note {
    my ($note, $class, %attrs) = @_;
    isa_ok($note, $class);
    is($note->$_, $attrs{$_})
        for keys %attrs;
    ok(defined $note->post_time);
}

1;

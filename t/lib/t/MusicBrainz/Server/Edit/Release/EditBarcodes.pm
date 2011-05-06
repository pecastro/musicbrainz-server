package t::MusicBrainz::Server::Edit::Release::EditBarcodes;
use Test::Routine;
use Test::More;

with 't::Context';

BEGIN { use MusicBrainz::Server::Edit::Release::EditBarcodes }

use MusicBrainz::Server::Constants qw( $EDIT_RELEASE_EDIT_BARCODES );
use MusicBrainz::Server::Test qw( accept_edit reject_edit );

test all => sub {

my $test = shift;
my $c = $test->c;

MusicBrainz::Server::Test->prepare_test_database($c, '+release');

my $edit = _create_edit($c);
isa_ok($edit, 'MusicBrainz::Server::Edit::Release::EditBarcodes');

my ($edits) = $c->model('Edit')->find({ release => [1, 2] }, 10, 0);
is(@$edits, 1);
is($edits->[0]->id, $edit->id);

my $r1 = $c->model('Release')->get_by_id(1);
my $r2 = $c->model('Release')->get_by_id(2);
is($r1->edits_pending, 3);
is($r1->barcode, '731453398122');
is($r2->edits_pending, 1);
is($r2->barcode, undef);

reject_edit($c, $edit);

$edit = _create_edit($c);
accept_edit($c, $edit);

$r1 = $c->model('Release')->get_by_id(1);
$r2 = $c->model('Release')->get_by_id(2);
is($r1->edits_pending, 2);
is($r1->barcode, '5099703257021');
is($r2->edits_pending, 0);
is($r2->barcode, '5199703257021');

};

sub _create_edit {
    my $c = shift;
    my $old_rel = $c->model('Release')->get_by_id(1);
    my $new_rel = $c->model('Release')->get_by_id(2);
    return $c->model('Edit')->create(
        edit_type => $EDIT_RELEASE_EDIT_BARCODES,
        editor_id => 1,
        submissions => [
            {
                release => {
                    id => $old_rel->id,
                    name => $old_rel->name,
                },
                barcode => '5099703257021',
            },
            {
                release => {
                    id => $new_rel->id,
                    name => $new_rel->name
                },
                barcode => '5199703257021'
            }
        ]
    );
}

1;

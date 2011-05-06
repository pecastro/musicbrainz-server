package t::MusicBrainz::Server::Edit::Label::AddAnnotation;
use Test::Routine;
use Test::More;

with 't::Context';

BEGIN { use MusicBrainz::Server::Edit::Label::AddAnnotation }

use MusicBrainz::Server::Constants qw( $EDIT_LABEL_ADD_ANNOTATION );
use MusicBrainz::Server::Test;

test all => sub {

my $test = shift;
my $c = $test->c;

MusicBrainz::Server::Test->prepare_test_database($c, '+annotation');

my $label = $c->model('Label')->get_by_id(1);
my $edit = $c->model('Edit')->create(
    edit_type => $EDIT_LABEL_ADD_ANNOTATION,
    editor_id => 1,

    entity => $label,
    text => 'Test annotation',
    changelog => 'A changelog',
);
isa_ok($edit, 'MusicBrainz::Server::Edit::Label::AddAnnotation');

my ($edits) = $c->model('Edit')->find({ label => 1 }, 10, 0);
is($edits->[0]->id, $edit->id);

$c->model('Edit')->load_all($edit);
is($edit->display_data->{label}->id, 1);
is($edit->display_data->{changelog}, 'A changelog');
is($edit->display_data->{annotation_id}, $edit->annotation_id);

$label = $c->model('Label')->get_by_id(1);
$c->model('Label')->annotation->load_latest($label);
my $annotation = $label->latest_annotation;
ok(defined $annotation);
is($annotation->editor_id, 1);
is($annotation->text, 'Test annotation');
is($annotation->changelog, 'A changelog');

my $annotation2 = $c->model('Label')->annotation->get_by_id($edit->annotation_id);
is_deeply($annotation, $annotation2);

};

1;

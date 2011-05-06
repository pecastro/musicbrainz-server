package t::MusicBrainz::Server::Data::WorkType;
use Test::Routine;
use Test::More;
use Test::Moose;
use Test::Memory::Cycle;

use MusicBrainz::Server::Data::WorkType;

use MusicBrainz::Server::Context;
use MusicBrainz::Server::Test;

with 't::Context';

test all => sub {

my $test = shift;
MusicBrainz::Server::Test->prepare_test_database($test->c, '+worktype');

my $wt_data = MusicBrainz::Server::Data::WorkType->new(c => $test->c);
memory_cycle_ok($wt_data);

my $wt = $wt_data->get_by_id(1);
is ( $wt->id, 1 );
is ( $wt->name, "Composition" );
memory_cycle_ok($wt_data);
memory_cycle_ok($wt);

$wt = $wt_data->get_by_id(2);
is ( $wt->id, 2 );
is ( $wt->name, "Symphony" );

my $wts = $wt_data->get_by_ids(1, 2);
is ( $wts->{1}->id, 1 );
is ( $wts->{1}->name, "Composition" );

is ( $wts->{2}->id, 2 );
is ( $wts->{2}->name, "Symphony" );

memory_cycle_ok($wt_data);
memory_cycle_ok($wts);

does_ok($wt_data, 'MusicBrainz::Server::Data::Role::SelectAll');
my @types = $wt_data->get_all;
is(@types, 2);
is($types[0]->id, 1);
is($types[1]->id, 2);

memory_cycle_ok($wt_data);
memory_cycle_ok(\@types);

};

1;

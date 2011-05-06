package t::MusicBrainz::Server::Data::ReleasePackaging;
use Test::Routine;
use Test::Moose;
use Test::More;
use Test::Memory::Cycle;

use MusicBrainz::Server::Data::ReleasePackaging;

use MusicBrainz::Server::Context;
use MusicBrainz::Server::Test;

with 't::Context';

test all => sub {

my $test = shift;
MusicBrainz::Server::Test->prepare_test_database($test->c, '+releasepackaging');

my $lt_data = MusicBrainz::Server::Data::ReleasePackaging->new(c => $test->c);
memory_cycle_ok($lt_data);

my $lt = $lt_data->get_by_id(1);
is ( $lt->id, 1 );
is ( $lt->name, "Jewel Case" );
memory_cycle_ok($lt_data);
memory_cycle_ok($lt);

my $lts = $lt_data->get_by_ids(1);
is ( $lts->{1}->id, 1 );
is ( $lts->{1}->name, "Jewel Case" );
memory_cycle_ok($lt_data);
memory_cycle_ok($lts);

does_ok($lt_data, 'MusicBrainz::Server::Data::Role::SelectAll');
my @types = $lt_data->get_all;
is(@types, 1);
is($types[0]->id, 1);
memory_cycle_ok($lt_data);
memory_cycle_ok(\@types);

};

1;

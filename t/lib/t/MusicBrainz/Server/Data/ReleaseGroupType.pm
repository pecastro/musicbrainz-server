package t::MusicBrainz::Server::Data::ReleaseGroupType;
use Test::Routine;
use Test::Moose;
use Test::More;
use Test::Memory::Cycle;

use MusicBrainz::Server::Data::ReleaseGroupType;

use MusicBrainz::Server::Context;
use MusicBrainz::Server::Test;

with 't::Context';

test all => sub {

my $test = shift;
MusicBrainz::Server::Test->prepare_test_database($test->c, '+releasegrouptype');

my $rgt_data = MusicBrainz::Server::Data::ReleaseGroupType->new(c => $test->c);
memory_cycle_ok($rgt_data);

my $rgt = $rgt_data->get_by_id(1);
is ( $rgt->id, 1 );
is ( $rgt->name, "Album" );
memory_cycle_ok($rgt_data);
memory_cycle_ok($rgt);

$rgt = $rgt_data->get_by_id(2);
is ( $rgt->id, 2 );
is ( $rgt->name, "Single" );

my $rgts = $rgt_data->get_by_ids(1, 2);
is ( $rgts->{1}->id, 1 );
is ( $rgts->{1}->name, "Album" );

is ( $rgts->{2}->id, 2 );
is ( $rgts->{2}->name, "Single" );

memory_cycle_ok($rgt_data);
memory_cycle_ok($rgts);

does_ok($rgt_data, 'MusicBrainz::Server::Data::Role::SelectAll');
my @types = $rgt_data->get_all;
is(@types, 2);
is($types[0]->id, 1);
is($types[1]->id, 2);

memory_cycle_ok($rgt_data);
memory_cycle_ok(\@types);

};

1;

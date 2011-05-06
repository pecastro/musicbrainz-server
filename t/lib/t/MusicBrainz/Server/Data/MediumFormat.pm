package t::MusicBrainz::Server::Data::MediumFormat;
use Test::Routine;
use Test::Moose;
use Test::More;
use Test::Memory::Cycle;

use MusicBrainz::Server::Data::MediumFormat;

use MusicBrainz::Server::Context;
use MusicBrainz::Server::Test;

with 't::Context';

test all => sub {

my $test = shift;
MusicBrainz::Server::Test->prepare_test_database($test->c, '+mediumformat');

my $mf_data = MusicBrainz::Server::Data::MediumFormat->new(c => $test->c);
memory_cycle_ok($mf_data);

my $mf = $mf_data->get_by_id(1);
is ( $mf->id, 1 );
is ( $mf->name, "CD" );
is ( $mf->year, 1982 );

memory_cycle_ok($mf_data);
memory_cycle_ok($mf);

$mf = $mf_data->get_by_id(2);
is ( $mf->id, 2 );
is ( $mf->name, "Vinyl" );
is ( $mf->year, undef );

my $mfs = $mf_data->get_by_ids(1, 2);
is ( $mfs->{1}->id, 1 );
is ( $mfs->{1}->name, "CD" );

is ( $mfs->{2}->id, 2 );
is ( $mfs->{2}->name, "Vinyl" );

memory_cycle_ok($mf_data);
memory_cycle_ok($mfs);

does_ok($mf_data, 'MusicBrainz::Server::Data::Role::SelectAll');
my @formats = $mf_data->get_all;
is(@formats, 4);
is($formats[0]->id, 1);
is($formats[1]->id, 2);

memory_cycle_ok($mf_data);
memory_cycle_ok(\@formats);

};

1;

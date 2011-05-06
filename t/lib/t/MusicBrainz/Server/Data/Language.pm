package t::MusicBrainz::Server::Data::Language;
use Test::Routine;
use Test::Moose;
use Test::More;
use Test::Memory::Cycle;

use MusicBrainz::Server::Data::Language;

use MusicBrainz::Server::Context;
use MusicBrainz::Server::Test;

with 't::Context';

test all => sub {

my $test = shift;
MusicBrainz::Server::Test->prepare_test_database($test->c, '+language');

my $language_data = MusicBrainz::Server::Data::Language->new(c => $test->c);
memory_cycle_ok($language_data);

my $language = $language_data->get_by_id(1);
is ( $language->id, 1 );
is ( $language->iso_code_3t, "deu" );
is ( $language->iso_code_3b, "ger" );
is ( $language->iso_code_2, "de" );
is ( $language->name, "German" );
memory_cycle_ok($language_data);
memory_cycle_ok($language);

my $languages = $language_data->get_by_ids(1);
is ( $languages->{1}->id, 1 );
is ( $languages->{1}->iso_code_3t, "deu" );
is ( $languages->{1}->iso_code_3b, "ger" );
is ( $languages->{1}->iso_code_2, "de" );
is ( $languages->{1}->name, "German" );
memory_cycle_ok($language_data);
memory_cycle_ok($languages);

does_ok($language_data, 'MusicBrainz::Server::Data::Role::SelectAll');
my @languages = $language_data->get_all;
is(@languages, 1);
is($languages[0]->id, 1);
memory_cycle_ok($language_data);
memory_cycle_ok(\@languages);

};

1;

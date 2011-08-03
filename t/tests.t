use strict;
use warnings FATAL => 'all';

use Module::Pluggable::Object;
use lib 't/lib';
use Test::More;
use Test::Routine::Util;

use MusicBrainz::Server::Test qw( commandline_override );

my $data_mpo = Module::Pluggable::Object->new(
    search_path => 't::MusicBrainz::Server::Data');

my $entity_mpo = Module::Pluggable::Object->new(
    search_path => 't::MusicBrainz::Server::Entity');

my $form_mpo = Module::Pluggable::Object->new(
    search_path => 't::MusicBrainz::Server::Form');

my @classes = (
    $data_mpo->plugins,
    $entity_mpo->plugins,
    $form_mpo->plugins
);

@classes = commandline_override ("t::MusicBrainz::Server::", @classes);

plan tests => scalar(@classes);
run_tests($_ => $_) for (@classes);


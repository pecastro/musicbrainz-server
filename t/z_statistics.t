use strict;
use warnings;
use Test::More;
use Test::Fatal;

use MusicBrainz::Server::Test;

BEGIN { use_ok 'MusicBrainz::Server::Data::Statistics' }

my $c = MusicBrainz::Server::Test->create_test_context;

$c->sql->begin;
ok !exception { $c->model('Statistics')->recalculate_all };
$c->sql->commit;

done_testing;

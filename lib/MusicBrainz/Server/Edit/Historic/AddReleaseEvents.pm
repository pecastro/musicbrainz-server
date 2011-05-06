package MusicBrainz::Server::Edit::Historic::AddReleaseEvents;
use strict;
use warnings;

use MusicBrainz::Server::Constants qw(
    $EDIT_HISTORIC_ADD_RELEASE_EVENTS
);
use MusicBrainz::Server::Translation qw ( l ln );

use base 'MusicBrainz::Server::Edit::Historic::EditReleaseEventsOld';

sub edit_name     { l('Add release events (historic)') }
sub edit_type     { $EDIT_HISTORIC_ADD_RELEASE_EVENTS }
sub historic_type { 49 }

1;

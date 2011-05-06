package MusicBrainz::Server::Edit::Historic::MergeReleaseMAC;
use strict;
use warnings;

use MusicBrainz::Server::Constants qw( $EDIT_HISTORIC_MERGE_RELEASE_MAC );
use MusicBrainz::Server::Translation qw ( l ln );

use base 'MusicBrainz::Server::Edit::Historic::MergeRelease';

sub edit_name     { l('Merge releases') }
sub historic_type { 25 }
sub edit_type     { $EDIT_HISTORIC_MERGE_RELEASE_MAC }

1;

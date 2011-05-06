package MusicBrainz::Server::Edit::Recording::Delete;
use Moose;

use MusicBrainz::Server::Constants qw( $EDIT_RECORDING_DELETE );
use MusicBrainz::Server::Translation qw( l ln );

extends 'MusicBrainz::Server::Edit::Generic::Delete';
with 'MusicBrainz::Server::Edit::Recording';
with 'MusicBrainz::Server::Edit::Recording::RelatedEntities';

sub edit_type { $EDIT_RECORDING_DELETE }
sub edit_name { l('Remove recording') }
sub _delete_model { 'Recording' }
sub recording_id { shift->entity_id }

__PACKAGE__->meta->make_immutable;
no Moose;

1;


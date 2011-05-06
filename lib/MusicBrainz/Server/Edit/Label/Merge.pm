package MusicBrainz::Server::Edit::Label::Merge;
use Moose;

use MusicBrainz::Server::Constants qw( $EDIT_LABEL_MERGE );
use MusicBrainz::Server::Translation qw( l ln );

extends 'MusicBrainz::Server::Edit::Generic::Merge';
with 'MusicBrainz::Server::Edit::Role::MergeSubscription';
with 'MusicBrainz::Server::Edit::Label';

sub edit_type { $EDIT_LABEL_MERGE }
sub edit_name { l('Merge labels') }

sub _merge_model { 'Label' }
sub subscription_model { shift->c->model('Label')->subscription }

__PACKAGE__->meta->make_immutable;
no Moose;

1;

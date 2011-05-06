package MusicBrainz::Server::Edit::Artist::Delete;
use Moose;

use MusicBrainz::Server::Constants qw( $EDIT_ARTIST_DELETE :expire_action :quality );
use MusicBrainz::Server::Translation qw ( l ln );

extends 'MusicBrainz::Server::Edit::Generic::Delete';
with 'MusicBrainz::Server::Edit::Role::DeleteSubscription';
with 'MusicBrainz::Server::Edit::Artist';

sub edit_name { l('Remove artist') }
sub edit_type { $EDIT_ARTIST_DELETE }

sub _delete_model { 'Artist' }
sub subscription_model { shift->c->model('Artist')->subscription }

# We do allow auto edits for this (as ModBot needs to insert them)
sub edit_conditions
{
    return {
        $QUALITY_LOW => {
            duration      => 4,
            votes         => 1,
            expire_action => $EXPIRE_ACCEPT,
            auto_edit     => 1,
        },
        $QUALITY_NORMAL => {
            duration      => 14,
            votes         => 3,
            expire_action => $EXPIRE_ACCEPT,
            auto_edit     => 1,
        },
        $QUALITY_HIGH => {
            duration      => 14,
            votes         => 4,
            expire_action => $EXPIRE_REJECT,
            auto_edit     => 0,
        },
    };
}


__PACKAGE__->meta->make_immutable;
no Moose;

1;

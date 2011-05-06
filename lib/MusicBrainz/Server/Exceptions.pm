package MusicBrainz::Server::Exceptions::InvalidInput;
use Moose;
extends 'Throwable::Error';

package MusicBrainz::Server::Exceptions::BadData;
use Moose;
extends 'MusicBrainz::Server::Exceptions::InvalidInput';

package MusicBrainz::Server::Exceptions::Duplicate;
use Moose;
extends 'MusicBrainz::Server::Exceptions::InvalidInput';

has 'duplicates' => ( is => 'ro', isa => 'ArrayRef' );

1;

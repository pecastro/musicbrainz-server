package MusicBrainz::Server::Form::ReleaseEditor::Duplicates;
use HTML::FormHandler::Moose;
extends 'MusicBrainz::Server::Form::Step';

has_field 'duplicate_id' => ( type => 'Integer' );

__PACKAGE__->meta->make_immutable;
1;

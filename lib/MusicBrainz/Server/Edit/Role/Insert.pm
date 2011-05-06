package MusicBrainz::Server::Edit::Role::Insert;
use Moose::Role;
use namespace::autoclean;

has 'entity_id' => (
    isa => 'Int',
    is  => 'rw'
);

override 'to_hash' => sub
{
    my $self = shift;
    my $hash = super(@_);
    $hash->{entity_id} = $self->entity_id;
    return $hash;
};

before 'restore' => sub
{
    my ($self, $hash) = @_;
    $self->entity_id(delete $hash->{entity_id});
};

1;

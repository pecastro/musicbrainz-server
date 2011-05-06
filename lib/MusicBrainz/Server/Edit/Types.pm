package MusicBrainz::Server::Edit::Types;
use strict;
use MooseX::Types -declare => [qw( ArtistCreditDefinition PartialDateHash )];
use MooseX::Types::Moose qw( ArrayRef Int Maybe );
use MooseX::Types::Structured qw( Dict Optional );
use Sub::Exporter -setup => { exports => [qw(
    ArtistCreditDefinition
    Changeset
    Nullable
    NullableOnPreview
    PartialDateHash
)] };

sub Nullable { (Optional[Maybe shift], @_) }

# This isn't (currently) any different from Nullable.  It only serves to document
# the intent.  For now, these still need to be validated elsewhere when setting the
# attribute.
sub NullableOnPreview { (Optional[Maybe shift], @_) }

sub Changeset
{
    my %fields = @_;
    return (
        old => Dict[%fields],
        new => Dict[%fields]
    )
}

subtype PartialDateHash,
    as Dict[
        year => Nullable[Int],
        month => Nullable[Int],
        day => Nullable[Int]
    ];

subtype ArtistCreditDefinition,
    as ArrayRef;

1;

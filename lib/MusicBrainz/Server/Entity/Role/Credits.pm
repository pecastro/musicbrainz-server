package MusicBrainz::Server::Entity::Role::Credits;

use Moose::Role;
use MusicBrainz::Server::Types;
use MusicBrainz::Server::Entity::Credit;

has 'credits' => (
    is => 'rw',
    isa => 'ArrayRef[Credit]',
    default => sub { [] },
    lazy => 1,
    traits => [ 'Array' ],
);

has 'combine_credit_contexts' => (
    is => 'rw',
    isa => 'CodeRef',
    default => sub { sub { return undef; } },
    lazy => 1,
);

sub add_credit
{
    my ($self, $phrase, $artist, $order, $context) = @_;

    my $cr = MusicBrainz::Server::Entity::Credit->new ();

    $cr->phrase($phrase);
    $cr->artist($artist);
    $cr->order($order);
    $cr->context($context) if $context;

    push @{$self->credits}, $cr;
}

sub credits_grouped
{
    my ($self) = @_;

    my %phrases;
    my @order;

    foreach (@{$self->credits})
    {
        $phrases{$_->phrase} = [] unless $phrases{$_->phrase};
        $order[$_->order] = {} unless $order[$_->order];

        $order[$_->order]->{$_->phrase} = 1;
        push @{$phrases{$_->phrase}}, $_;
    } 

    my @credits;

    # group credits by linktype->childorder order.
    foreach my $group (@order)
    {
        # group artists by link phrase.
        foreach my $phrase (keys %$group)
        {
            my %artists;

            # group credit context by artist.
            foreach (@{$phrases{$phrase}})
            {
                $artists{$_->artist->id} = {
                    artist => $_->artist,
                    context => [],
                    phrase => $phrase
                } unless $artists{$_->artist->id};

                push @{$artists{$_->artist->id}->{context}}, $_->context
                    if $_->context;
            }

            my @artists = values %artists;
            foreach (@artists)
            {
                $_->{context} = $self->combine_credit_contexts->($_->{context});
            }

            push @credits, \@artists;
        }
    }

    return \@credits;
}

no Moose::Role;
1;

=head1 COPYRIGHT

Copyright (C) 2010 MetaBrainz Foundation

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut


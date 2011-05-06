package MusicBrainz::Server::Data::FreeDB;
use Moose;

use constant FREEDB_PROTOCOL => 6; # speaks UTF-8

use aliased 'MusicBrainz::Server::Entity::FreeDB';

use Carp 'confess';
use LWP::UserAgent;
use URI;

with 'MusicBrainz::Server::Data::Role::Context';

has servers => (
    is => 'bare',
    traits => [ 'Array' ],
    handles => {
        servers => 'elements',
    },
    default => sub { [
        'freedb2.org',
        'freedb.freedb.org'
    ] }
);

sub _entity_class { 'MusicBrainz::Server::Entity::FreeDB' }

sub lookup {
    my ($self, $category, $id) = @_;
    for my $server ($self->servers) {
        my $response = $self->read($server, $category, $id) or next;
        return $response;
    }
}

sub read {
    my ($self, $server, $category, $id) = @_;
    $self->_cached_command(
        $server,
        "cddb read $category $id",
        \&_do_read
    )
}

sub _do_read {
    my ($self, $response) = @_;

    # Extract all key-value pairs in the FreeDB data
    my %data = map { split /=/, $_, 2 }
        grep { /^[A-Z0-9]+=/ }
        split /\r\n/, $response->decoded_content;

    # Extract all track offsets
    my @offsets = map { /^#\s+(\d+)$/; $1; }
        grep { /^#\s+\d+$/ }
        split /\r\n/, $response->decoded_content;

    # Extract the disc duration and add it as the final frame offset
    my ($disc_duration) = map { /(\d+)/; $1; }
        grep { /^#\s+Disc length:/ }
        split /\r\n/, $response->decoded_content;

    push @offsets, $disc_duration * 75;

    # Attempt to determine the release title and artist
    my $split = qr{ [\/-] };
    my ($release_artist, $title);
    my $va;
    if ($data{DTITLE} =~ $split) {
        ($release_artist, $title) = split $split, $data{DTITLE}, 2;
    }
    else {
        ($release_artist, $title) = ('', $data{DTITLE});
        $va = 1;
    }

    # Extract each track
    my @tracks;
    for my $i (0..99) {
        exists $data{"TTITLE$i"} or next;
        my $track = $data{"TTITLE$i"};
        $track =~ s/^\d+\.\s*//; # Trim leading track numbers

        my ($artist, $title);
        if ($track =~ $split) {
            ($artist, $title) = split $split, $track, 2;
            $va = 1;
        }
        else {
            ($artist, $title) = ($release_artist, $track);
        }

        push @tracks, {
            artist => $artist,
            title => $title,
            freedb_title => $track,
            length => int((($offsets[$i + 1] - $offsets[$i]) * 1000) / 75)
        };
    }

    # Structure data and return a FreeDB entity
    return FreeDB->new(
        tracks => \@tracks,
        discid => $data{DISCID},
        track_count => scalar(@tracks),
        artist => 2,
        year => $data{DYEAR},
        title => $title,
        artist => $release_artist,
        looks_like_va => $va
    );
}

sub _cached_command
{
    my ($self, $server, $command, $response_parser) = @_;

    my $cache_key = "FreeDB-$server-$command";
    my $cache = $self->c->cache('freedb');

    if (my $r = $cache->get($cache_key)) {
	    return $r;
    }
    else {
        my $r;
        if (my $response = $self->_retrieve_no_cache($server, $command)) {
            $r = $self->$response_parser($response);
        }

        $cache->set($cache_key => $r);
        return $r;
    }
}

sub _retrieve_no_cache
{
    my ($self, $server, $command) = @_;

    confess "A server address/name must be given."
        if ($server eq '');

    my $url = URI->new("http://$server/~cddb/cddb.cgi");
    $url->query_form([
        cmd => $command,
        hello => 'webmaster musicbrainz.org musicbrainz.org 1.0',
        proto => FREEDB_PROTOCOL
    ]);

    my $ua = LWP::UserAgent->new(max_redirect => 0);
	$ua->env_proxy;
    my $response = $ua->get($url);

    return undef unless $response->is_success;

    if ($response->code == 202 || $response->code < 200 || $response->code > 299) {
        return undef;
    }

    return $response;
}

sub normalize_disc_numbers
{
    my ($self, $name) = @_;
    my ($new, $disc);

    if ($name =~ /^(.*)(\(|\[)\s*(disk|disc|cd)\s*(\d+|one|two|three|four)(\)|\])$/i) {
        $new = $1;
        $disc = $4;
    }
    elsif ($name =~ /^(.*)(disk|disc|cd)\s*(\d+|one|two|three|four)$/i) {
        $new = $1;
        $disc = $3;
    }

    if (defined $new && defined $disc)
    {
        $disc = 1 if ($disc =~ /one/i);
        $disc = 2 if ($disc =~ /two/i);
        $disc = 3 if ($disc =~ /three/i);
        $disc = 4 if ($disc =~ /four/i);
        if ($disc > 0 && $disc < 100)
        {
            $disc =~ s/^0+//g;
            $new =~ s/\s*[(\/|:,-]*\s*$//;
            $new .= " (disc $disc)";

            return $new;
        }
    }

    return $name;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=head1 COPYRIGHT

Copyright (C) 2010 Robert Kaye
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

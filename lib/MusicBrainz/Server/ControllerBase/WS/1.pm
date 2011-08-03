package MusicBrainz::Server::ControllerBase::WS::1;

use Moose;
use Readonly;
BEGIN { extends 'MusicBrainz::Server::Controller'; }

use DBDefs;
use HTTP::Status qw( :constants );
use MusicBrainz::Server::Data::Utils qw( model_to_type );
use MusicBrainz::Server::Exceptions;
use MusicBrainz::Server::WebService::XMLSerializerV1;
use Try::Tiny;

with 'MusicBrainz::Server::Controller::Role::Profile' => {
    threshold => DBDefs::PROFILE_WEB_SERVICE()
};

has 'model' => (
    isa => 'Str',
    is  => 'ro',
);

sub serializers {
    return {
        xml => 'MusicBrainz::Server::WebService::XMLSerializerV1',
    };
}

sub apply_rate_limit
{
    my ($self, $c, $key) = @_;
    $key ||= "ws ip=" . $c->request->address;

    my $r = $c->model('RateLimiter')->check_rate_limit($key);
    if ($r && $r->is_over_limit) {
        $c->response->status(HTTP_SERVICE_UNAVAILABLE);
        $c->res->content_type("text/plain; charset=utf-8");
        $c->res->headers->header(
            'X-Rate-Limited' => sprintf('%.1f %.1f %d', $r->rate, $r->limit, $r->period)
        );
        $c->response->body(
            "Your requests are exceeding the allowable rate limit (" . $r->msg . ")\015\012" .
            "Please see http://wiki.musicbrainz.org/XMLWebService for more information.\015\012"
        );
        $c->detach;
    }

    $r = $c->model('RateLimiter')->check_rate_limit('ws global');
    if ($r && $r->is_over_limit) {
        $c->response->status(HTTP_SERVICE_UNAVAILABLE);
        $c->res->content_type("text/plain; charset=utf-8");
        $c->res->headers->header(
            'X-Rate-Limited' => sprintf('%.1f %.1f %d', $r->rate, $r->limit, $r->period)
        );
        $c->response->body(
            "The MusicBrainz web server is currently busy.\015\012" .
            "Please try again later.\015\012"
        );
        $c->detach;
    }
}

sub begin : Private {
    my ($self, $c) = @_;
    $c->stash->{data} = {};
    $self->validate($c, $self->serializers) or $c->detach('bad_req');
    $self->apply_rate_limit($c);
}

sub root : Chained('/') PathPart('ws/1') CaptureArgs(0) { }

sub search : Chained('root') PathPart('')
{
    my ($self, $c) = @_;

    my $limit = 0 + ($c->req->query_params->{limit} || 25);
    $limit = 25 if $limit < 1 || $limit > 100;

    my $offset = 0 + ($c->req->query_params->{offset} || 0);
    $offset = 0 if $offset < 0;

    try {
        my $body = $c->model('Search')->xml_search(
            %{ $c->req->query_params },

            limit   => $limit,
            offset  => $offset,
            type    => model_to_type($self->model),
            version => 1,
        );
        $c->res->body($body);
    }
    catch {
        my $err = $_;
        if (blessed($err) && $err->isa('MusicBrainz::Server::Exceptions::InvalidSearchParameters')) {
            $c->res->body($err->message);
            $c->res->status(HTTP_BAD_REQUEST);
        }
        else {
            die $err;
        }
    };

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
}

# Don't render with TT
sub end : Private { }

sub bad_req : Private
{
    my ($self, $c, $error) = @_;
    $c->res->status(HTTP_BAD_REQUEST);
    $c->res->content_type("text/plain; charset=utf-8");
    $c->res->body($c->stash->{serializer}->output_error($error || $c->stash->{error}));
    $c->detach;
}

sub deny_readonly : Private
{
    my ($self, $c) = @_;
    if(DBDefs::DB_READ_ONLY) {
        $c->res->status(HTTP_SERVICE_UNAVAILABLE);
        $c->res->content_type("text/plain; charset=utf-8");
        $c->res->body($c->stash->{serializer}->output_error("The database is currently in readonly mode and cannot handle your request"));
        $c->detach;
    }
}


sub load : Chained('root') PathPart('') CaptureArgs(1)
{
    my ($self, $c, $gid) = @_;

    if (!MusicBrainz::Server::Validation::IsGUID($gid))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $entity = $c->model($self->model)->get_by_gid($gid)
        or $c->detach('not_found');

    $c->stash->{entity} = $entity;
}

sub not_found : Private
{
    my ($self, $c) = @_;
    $c->res->status(404);
    $c->detach;
}

no Moose;
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

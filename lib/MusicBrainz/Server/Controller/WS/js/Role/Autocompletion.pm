package MusicBrainz::Server::Controller::WS::js::Role::Autocompletion;
use Moose::Role;
use namespace::autoclean;

use Encode;
use MusicBrainz::Server::Data::Utils qw( type_to_model );
use MusicBrainz::Server::Data::Search qw( escape_query );
use Text::Trim;
use Text::Unaccent qw( unac_string_utf16 );

requires 'type';

sub serialization_routine { 'autocomplete_generic' }

sub model {
    my ($self, $c) = @_;
    return $c->model(type_to_model($self->type));
}

sub dispatch_search {
    my ($self, $c) = @_;

    my $query = trim $c->stash->{args}->{q};
    my $limit = $c->stash->{args}->{limit} || 10;
    my $page = $c->stash->{args}->{page} || 1;
    my $direct = $c->stash->{args}->{direct} || '';

    unless ($query) {
        $c->detach('bad_req');
    }

    my ($output, $pager) =
        $direct eq 'true' ? $self->_direct_search($c, $query, $page, $limit)
                          : $self->_indexed_search($c, $query, $page, $limit);

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize($self->serialization_routine, $output, $pager));
}

sub _load_entities { }

sub _do_direct_search {
    my ($self, $c, $query, $offset, $limit) = @_;
    return $c->model ('Search')->search (
        $self->type, $query, $limit, $offset);
}

sub _direct_search {
    my ($self, $c, $query, $page, $limit) = @_;

    my $offset = ($page - 1) * $limit;  # page is not zero based.
    my ($search_results, $hits) = $self->_do_direct_search($c, $query, $offset, $limit);

    my @entities = map { $_->entity } @$search_results;
    $self->_load_entities($c, @entities);

    my @output = $self->_format_output($c, @entities);

    my $pager = Data::Page->new ();
    $pager->entries_per_page ($limit);
    $pager->current_page ($page);
    $pager->total_entries ($hits);

    return (\@output, $pager);
}

sub _format_output {
    my ($self, $c, @entities) = @_;
    return @entities;
}

sub _form_indexed_query {
    my ($self, $query) = @_;
    $query = decode ("utf-16", unac_string_utf16 (encode ("utf-16", $query)));
    $query = escape_query ($query);

    # FIXME Should be able to remove the 'OR' when Lucene 4.0 comes out
    $query = "$query OR $query*";

    return $query;
}

sub _indexed_search {
    my ($self, $c, $query, $page, $limit) = @_;

    $query = $self->_form_indexed_query($query, $c);

    my $model = $self->model($c);

    my $no_redirect = 1;
    my $response = $c->model ('Search')->external_search (
        $self->type, $query, $limit, $page, 1, undef);

    my (@output, $pager);

    if ($response->{pager})
    {
        $pager = $response->{pager};

        for my $result (@{ $response->{results} })
        {
            my $entity = $model->get_by_gid ($result->{entity}->gid) if $result->entity->{gid};
            next unless $entity;
            push @output, $entity;
        }

        $self->_load_entities($c, @output);
    }
    else
    {
        # If an error occurred just ignore it for now and return an
        # empty list.  The javascript code for autocomplete doesn't
        # have any way to gracefully report or deal with
        # errors. --warp.

        $pager = Data::Page->new;
        $pager->entries_per_page ($limit);
        $pager->current_page ($page);
        $pager->total_entries (0);
    }

    return ([ $self->_format_output($c, @output) ], $pager);
}

1;

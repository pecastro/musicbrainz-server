package MusicBrainz::Server::Controller::User;
use Moose;

BEGIN { extends 'MusicBrainz::Server::Controller' };

use Digest::SHA1 qw(sha1_base64);
use Encode;
use MusicBrainz::Server::Authentication::User;
use MusicBrainz::Server::Data::Utils qw( type_to_model );
use MusicBrainz::Server::Translation qw ( l ln );

with 'MusicBrainz::Server::Controller::Role::Subscribe';

use MusicBrainz::Server::Types qw(
    $BOT_FLAG
    $AUTO_EDITOR_FLAG
    $WIKI_TRANSCLUSION_FLAG
    $RELATIONSHIP_EDITOR_FLAG
);

with 'MusicBrainz::Server::Controller::Role::Load' => {
    entity_name => 'user',
    model => 'Editor'
};

__PACKAGE__->config(
    paging_limit => 25,
);

use Try::Tiny;

=head1 NAME

MusicBrainz::Server::Controller::User - Catalyst Controller to handle
user authentication and profile management

=head1 DESCRIPTION

The user controller handles users logging in and logging out, the
registration or administration of accounts, and the viewing/updating of
profile pages.

=head1 METHODS

=head2 index

If the user is currently logged in redirect them to their profile page,
otherwise redirect the user to the login page.

=cut

sub index : Private
{
    my ($self, $c) = @_;

    # Can't set an attribute on a private action; manually inserting detatch code.
    $c->detach('/error_mirror_404') if ($c->stash->{server_details}->{is_slave_db});

    $c->forward('login');
    $c->detach('/user/profile', [ $c->user->name ]);
}

sub do_login : Private
{
    my ($self, $c) = @_;
    return 1 if $c->user_exists;

    my $form = $c->form(form => 'User::Login');
    my $redirect = defined $c->req->query_params->{uri}
        ? $c->req->query_params->{uri}
        : $c->relative_uri;

    if ($c->form_posted && $form->process(params => $c->req->params))
    {
        if( !$c->authenticate({ username => $form->field("username")->value,
                                password => $form->field("password")->value }) )
        {
            # Bad username / password combo
            $c->log->info('Invalid username/password');
            $c->stash( bad_login => 1 );
        }
        else
        {
            if ($form->field('remember_me')->value) {
                $self->_set_login_cookie($c);
            }

            # Logged in OK
            $c->response->redirect($redirect);
            $c->detach;
        }
    }

    # Form not even posted
    $c->stash(
        template => 'user/login.tt',
        login_form => $form,
        redirect => $redirect,
    );

    $c->stash->{required_login} = 1
        unless exists $c->stash->{required_login};

    $c->detach;
}

sub login : Path('/login') ForbiddenOnSlaves
{
    my ($self, $c) = @_;

    if ($c->user_exists) {
        $c->response->redirect($c->uri_for_action('/user/profile',
                                                 [ $c->user->name ]));
        $c->detach;
    }

    $c->stash( required_login => 0 );
    $c->forward('/user/do_login');
}

sub cookie_login : Private
{
    my ($self, $c) = @_;
    my $cookie = $c->req->cookie('remember_login') or return;
    return unless $cookie->value;
    return if $c->user_exists;

    my ($user_name, $password, $delete_cookie);

    # Format 1: plaintext user + password
    try {
        if ($cookie->value =~ /^1\t(.*?)\t(.*)$/) {
            ($user_name, $password) = ($1, $2);
        }
        # Format 2: username, sha1(password + secret), expiry time,
        # IP address mask, sha1(previous fields + secret)
        elsif ($cookie->value =~ /^2\t(.*?)\t(\S+)\t(\d+)\t(\S*)\t(\S+)$/)
        {
            $c->log->info('Found version 2 format cookie');
            ($user_name, my $pass_sha1, my $expiry, my $ipmask, my $sha1)
                = ($1, $2, $3, $4, $5);

            my $correct_sha1 = sha1_base64("2\t$1\t$2\t$3\t$4" . DBDefs::SMTP_SECRET_CHECKSUM);
            die "Invalid cookie sha1"
                unless $sha1 eq $correct_sha1;

            die "Expired"
                if time() > $expiry;

            my $user = $c->model('Editor')->get_by_name($user_name) or last;

            my $correct_pass_sha1 = sha1_base64($user->password . "\t" . DBDefs::SMTP_SECRET_CHECKSUM);
            die "Password sha1 do not match"
                unless $pass_sha1 eq $correct_pass_sha1;

            $password = $user->password;
        }
        else {
            # TODO add other formats: e.g. sha1(password), tied to IP, etc
            die "Didn't recognise permanent cookie format";
        }

        $c->authenticate({ username => $user_name, password => $password });
    }
    catch {
        $c->log->error($_);
    };
}

sub _clear_login_cookie
{
    my ($self, $c) = @_;
    $c->res->cookies->{remember_login} = {
        value => '',
        expires => '+1y',
    };
}

sub _set_login_cookie
{
    my ($self, $c) = @_;
    my $expiry_time = time + 86400 * 635;
    my $password_sha1 = sha1_base64($c->user->password . "\t" . DBDefs::SMTP_SECRET_CHECKSUM);
    my $ip_mask = '';
    my $value = sprintf("2\t%s\t%s\t%s\t%s", $c->user->name, $password_sha1,
                                             $expiry_time, $ip_mask);
    $c->res->cookies->{remember_login} = {
        expires => '+1y',
        name => 'remember_me',
        value => encode('utf-8', $value) . "\t" . sha1_base64(encode('utf-8', $value) . DBDefs::SMTP_SECRET_CHECKSUM)
    };
}

sub logout : Path('/logout')
{
    my ($self, $c) = @_;

    if ($c->user_exists) {
        $c->logout;
        $c->delete_session;
        $self->_clear_login_cookie($c);
    }

    $self->redirect_back($c, '/logout', '/');
}

sub base : Chained PathPart('user') CaptureArgs(0) HiddenOnSlaves { }

sub _load
{
    my ($self, $c, $user_name) = @_;

    my $user = $c->model('Editor')->get_by_name($user_name) or return;
    $c->stash->{viewing_own_profile} = $c->user_exists && $c->user->id == $user->id;
    $c->stash->{show_flags}          = $c->user_exists && $c->user->is_account_admin;

    return $user;
}

=head2 contact

Allows users to contact other users via email

=cut

sub contact : Chained('load') RequireAuth HiddenOnSlaves
{
    my ($self, $c) = @_;

    my $editor = $c->stash->{user};
    unless ($editor->email) {
        $c->stash(
            title    => $c->gettext('Send Email'),
            message  => l('The editor {name} has no email address attached to their account.',
                         { name => $editor->name }),
            template => 'user/message.tt',
        );
        $c->detach;
    }

    if (exists $c->req->params->{sent}) {
        $c->stash( template => 'user/email_sent.tt' );
        $c->detach;
    }

    my $form = $c->form( form => 'User::Contact' );
    if ($c->form_posted && $form->process( params => $c->req->params )) {

        my $result;
        try {
            $result = $c->model('Email')->send_message_to_editor(
                from           => $c->user,
                to             => $editor,
                subject        => $form->value->{subject},
                message        => $form->value->{body},
                reveal_address => $form->value->{reveal_address},
                send_to_self   => $form->value->{send_to_self},
            );
        }
        catch {
            $c->flash->{message} = l('Your message could not be sent');
        };

        $c->res->redirect($c->uri_for_action('/user/contact', [ $editor->name ], { sent => $result }));
        $c->detach;
    }
}

sub collections : Chained('load') PathPart('collections')
{
    my ($self, $c) = @_;

    my $user = $c->stash->{user};

    my $show_private = $c->stash->{viewing_own_profile};

    my $collections = $self->_load_paged($c, sub {
        $c->model('Collection')->find_by_editor($user->id, $show_private, shift, shift);
    });

    $c->stash(
        user => $user,
        collections => $collections,
    );
}

sub profile : Chained('load') PathPart('') HiddenOnSlaves
{
    my ($self, $c) = @_;

    my $user = $c->stash->{user};

    my $subscr_model = $c->model('Editor')->subscription;
    $c->stash->{subscribed}       = $c->user_exists && $subscr_model->check_subscription($c->user->id, $user->id);
    $c->stash->{subscriber_count} = $subscr_model->get_subscribed_editor_count($user->id);
    $c->stash->{votes}            = $c->model('Vote')->editor_statistics($user->id);

    $c->stash(
        user     => $user,
        template => 'user/profile.tt',
    );
}

sub ratings : Chained('load') PathPart('ratings') HiddenOnSlaves
{
    my ($self, $c) = @_;

    my $user = $c->stash->{user};

    if (!defined $c->user || $c->user->id != $user->id)
    {
        $c->model('Editor')->load_preferences($user);
        $c->detach('/error_403')
            unless $user->preferences->public_ratings;
    }

    my $ratings = $c->model('Editor')->get_ratings($user,
                        $c->stash->{viewing_own_profile});

    $c->stash(
        user => $user,
        ratings => $ratings,
        template => 'user/ratings.tt',
    );
}

sub tags : Chained('load') PathPart('tags')
{
    my ($self, $c) = @_;

    my $user = $c->stash->{user};

    if (!defined $c->user || $c->user->id != $user->id)
    {
        $c->model('Editor')->load_preferences($user);
        $c->detach('/error_403')
            unless $user->preferences->public_tags;
    }

    my $tags = $c->model('Editor')->get_tags ($user);

    use List::Util 'sum';
    $c->stash(
        user => $user,
        tags => $tags,
        tag_max_count => sum(map { $_->{count} } @{ $tags->{tags} }),
        template => 'user/tags.tt',
    );
}

sub tag : Chained('load') PathPart('tags') Args(1)
{
    my ($self, $c, $tag_name) = @_;
    my $user = $c->stash->{user};
    my $tag = $c->model('Tag')->get_by_name($tag_name);

    if ($tag) {
        $c->stash(
            tag => $tag,
            map {
                $_ => [ $c->model(type_to_model($_))
                    ->tags->find_editor_entities($user->id, $tag->id)
                ]
            } qw( artist label recording release_group work )
        );
    }
}


sub privileged : Path('/privileged')
{
    my ($self, $c) = @_;

    $c->stash(
        bots => [
            $c->model ('Editor')->find_by_privileges ($BOT_FLAG)
        ],
        auto_editors => [
            $c->model ('Editor')->find_by_privileges ($AUTO_EDITOR_FLAG)
        ],
        transclusion_editors => [
            $c->model ('Editor')->find_by_privileges ($WIKI_TRANSCLUSION_FLAG)
        ],
        relationship_editors => [
            $c->model ('Editor')->find_by_privileges ($RELATIONSHIP_EDITOR_FLAG)
        ],
        template => 'user/privileged.tt',
    );
}

1;

1;

=head1 COPYRIGHT

Copyright (C) 2009 Oliver Charles
Copyright (C) 2009 Lukas Lalinsky

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

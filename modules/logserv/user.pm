# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::logserv::user;

use strict;
use warnings;
use 5.010;

our $svs;

our $mod = API::Module->new(
    name         => 'logserv/user',
    version      => '1.0',
    description  => 'Logs user related events.',
    requirements => ['Logger', 'Event'],
    dependencies => ['logserv/main'], 
    initialize   => \&init,
    void         => \&void
);

sub init {
    $mod::svs = $svs = IRC->get_service('logserv');
    # Sanity checking.
    $mod->log(MODLOAD_ERROR => 'Refusing to load. Log service could not be found.') and return if !$svs;
    # Create bindings.
    $mod->bind_event(irc_connect => \&on_connect, 'logserv.connect') unless $::conf->get('service:logserv:disable_connect');
    $mod->bind_event(irc_hostchange => \&on_hostchange, 'logserv.hostchange') unless $::conf->get('service:logserv:disable_hostchange');
    $mod->bind_event(irc_nick => \&on_nick, 'logserv.nick') unless $::conf->get('service:logserv:disable_nick');
    $mod->bind_event(irc_quit => \&on_quit, 'logserv.quit') unless $::conf->get('service:logserv:disable_quit');
    $mod->bind_event(irc_away => \&on_away, 'logserv.away') unless $::conf->get('service:logserv:disable_away');
    $mod->bind_event(irc_back => \&on_back, 'logserv.back') unless $::conf->get('service:logserv:disable_away');
    # We're good.
    return 1;
}

sub void {
    return 1;
}

sub on_hostchange {
    my ($user, $new) = @_;
    $svs->logchan("\2HOST CHANGE:\2 $$user{nick}'s host was changed from $$user{mask} to $new");
}

sub on_nick {
    my ($user, $new) = @_;
    $svs->logchan("\2\00312NICK:\003\2 $$user{nick} changed their nickname to $new");
}

sub on_quit {
    my ($user, $reason) = @_;
    $svs->logchan("\2\00304QUIT:\003\2 $$user{nick}!$$user{ident}\@$$user{host} quit: $reason");
}

sub on_connect {
    my $user = shift;
    return if $user->server->bursting; # Ignore user connects when bursting.
    my $server = $user->server->name;
    $svs->logchan("\2\00309CONNECT:\003\2 $$user{nick}!$$user{ident}\@$$user{host} [\2IP:\2 $$user{ip} \2GECOS:\2 $$user{gecos} \2Server:\2 $server]");
}

sub on_away {
    my ($user, $reason) = @_;
    return if $user->server->bursting; # Ignore away when bursting.
    my $string = ($user->{away} ? "$$user{nick} changed their away reason to $reason" : "$$user{nick} is now away: $reason");
    $svs->logchan("\2AWAY:\2 $string");
}

sub on_back {
    my $user = shift;
    $svs->logchan("\2AWAY:\2 $$user{nick} has returned from away.");
}

$mod;

# vim: set ai et sw=4 ts=4:

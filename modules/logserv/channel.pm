# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::logserv::channel;

use strict;
use warnings;
use 5.010;

our $svs;

our $mod = API::Module->new(
    name         => 'logserv/channel',
    version      => '1.0',
    description  => 'Logs channel related events.',
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
    $mod->bind_event(irc_join => \&on_join, 'logserv.join') unless $::conf->get('service:logserv:disable_join');
    $mod->bind_event(irc_part => \&on_part, 'logserv.part') unless $::conf->get('service:logserv:disable_part');
    $mod->bind_event(irc_chancreate => \&on_chancreate, 'logserv.chancreate') unless $::conf->get('service:logserv:disable_chancreate');
    $mod->bind_event(irc_chandelete => \&on_chandelete, 'logserv.chandelete') unless $::conf->get('service:logserv:disable_chandelete');
    # We're good.
    return 1;
}

sub void {
    return 1;
}

sub on_join {
    my ($user, $chan) = @_;
    return if !$main::proto::synced; # Bail if bursting isn't complete.
    $svs->logchan("\2JOIN:\2 $$user{nick} joined $$chan{name}.");
}

sub on_part {
    my ($user, $chan) = @_;
    my $reason = (defined $_[2] ? $_[2] : 'No reason.');
    $svs->logchan("\2PART:\2 $$user{nick} parted $$chan{name} ($reason).");
}

sub on_chancreate {
    my $chan = shift;
    return if !$main::proto::synced; # Bail if bursting isn't complete.
    my $string = (defined $_[0] ? "${$_[0]}{nick} created channel $$chan{name}." : "Channel $$chan{name} created.");
    $svs->logchan("\2CHANNEL CREATION:\2 $string");
}

sub on_chandelete {
    my $chan = shift;
    $svs->logchan("\2CHANNEL DELETION:\2 $$chan{name}");
}

$mod;

# vim: set ai et sw=4 ts=4:

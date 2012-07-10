# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package IRC;

use warnings;
use strict;
use base 'EventedObject';

use IRC::Channel;
use IRC::Service;
use IRC::Server;
use IRC::User;
use IRC::Mode;

our $irc = IRC->new;

sub new {
    return bless {
        users    => {},
        channels => {},
        servers  => {}
    }, shift;
}

# Add an IRC::User to this IRC instance
sub add_user {
    my ($irc, $user) = &args;
    return if !$user->isa('IRC::User');
    $irc->{users}->{$user->{id}} = $user;
    if ($user->is_service) {
        my %opts;
        $opts{$_} = $user->{$_} foreach qw|nick ident host gecos id|;
        if (!$main::proto::synced) {
            $main::proto->on(burst_start => sub {
                $main::proto->fire(irc_create_user => %opts);
                $main::proto->delete_event('irc.burst.start');
            }, 'irc.burst_start');
        }
        else {
            $main::proto->fire(irc_create_user => %opts);
        }
    }        
}

# Create a new IRC::User and add it to this IRC instance
sub create_user {
    my ($irc, %opts) = &args;
    my $user = IRC::User->new(%opts);
    $irc->add_user($user);
    return $user;
}

# Get a user object from id
sub get_user_from_id {
    my ($irc, $id) = &args;
    return if !defined $irc->{users}->{$id};
    return $irc->{users}->{$id};
}

# Get a user from his nick
sub get_user_from_nick {
    my ($irc, $nick) = &args;
    return (grep { lc $_->{nick} eq lc $nick } values %{$irc->{users}})[0];
}

# Gets users from a server object.
sub get_users_from_server {
    my ($irc, $server) = &args;
    return (grep { $_->{server} == $server } values %{$irc->{users}});
}

# Delete a user
sub delete_user {
    my ($irc, $user) = &args;
    foreach (keys %{$irc->{users}}) {
        if ($irc->{users}->{$_} == $user) {
            foreach (@{$user->channels}) {
                $_->delete_user($user);
            }
            delete $irc->{users}->{$_};
        }
    }
    return $user;
}

# Add an IRC::Channel to this IRC instance
sub add_channel {
    my ($irc, $channel) = &args;
    return if !$channel->isa('IRC::Channel');
    $irc->{channels}->{$channel->{id}} = $channel;
}

# Create a new IRC::Channel and add it to this IRC instance
sub create_channel {
    my ($irc, %opts) = &args;
    my $channel = IRC::Channel->new(%opts);
    $irc->add_channel($channel);
    return $channel;
}

# Get a channel object from id
sub get_channel_from_id {
    my ($irc, $id) = &args;
    $id = lc $id;
    return if !defined $irc->{channels}->{$id};
    return $irc->{channels}->{$id};
}

# Delete a channel
sub delete_channel {
    my ($irc, $chan) = &args;
    foreach (keys %{$irc->{channels}}) {
        if ($irc->{channels}->{$_} == $chan) {
            foreach (@{$chan->users}) {
                $_->delete_chan($chan);
            }
            delete $irc->{channels}->{$_};
        }
    }
    return $chan;
}


# Add an IRC::Server to this IRC instance
sub add_server {
    my ($irc, $server) = &args;
    return if !$server->isa('IRC::Server');
    $irc->{servers}->{$server->{id}} = $server;
}

# Create a new IRC::Server and add it to this IRC instance
sub create_server {
    my ($irc, %opts) = &args;
    my $server = IRC::Server->new(%opts);
    $irc->add_server($server);
    return $server;
}

# Get a server object from id
sub get_server_from_id {
    my ($irc, $id) = &args;
    return if !defined $irc->{servers}->{$id};
    return $irc->{servers}->{$id};
}

# Get a server object from name
sub get_server_from_name {
    my ($irc, $name) = &args;
    return (grep { lc $_->{name} eq lc $name } values %{$irc->{servers}})[0];
}

# Get a server objects from parent.
sub get_servers_from_parent {
    my ($irc, $id) = &args;
    return (grep { $_->{parent} == $id } values %{$irc->{servers}});
}

# Delete a server
sub delete_server {
    my ($irc, $server) = &args;
    foreach (keys %{$irc->{servers}}) {
        if ($irc->{servers}->{$_} == $server) {
            foreach my $user ($irc->get_users_from_server($server)) {
                $irc->delete_user($user);
            }
            delete $irc->{servers}->{$_};
        }
    }
    return $server;
}

# Create a new IRC::Service and add it to this IRC instance
sub create_service {
    my ($irc, %opts) = &args;
    my $service = IRC::Service->new(%opts);
    $irc->add_user($service);
    return $service;
}

# Get a service from his service name
sub get_service {
    my ($irc, $name) = &args;
    return (grep { if (defined $_->{service}) { lc $_->{service} eq lc $name } } values %{$irc->{users}})[0];
}

# Create a new channel IRC::Mode and add it to this IRC instance
sub create_channel_mode {
    my ($irc, %opts) = &args;
    my $mode = IRC::Mode->new(%opts) or return;
    $irc->add_channel_mode($mode);
    return $mode;
}

# Add a channel IRC::Mode to this IRC instance
sub add_channel_mode {
    my ($irc, $mode) = &args;
    return if !$mode->isa('IRC::Mode');
    $irc->{channel_modes}->{$mode->{name}} = $mode;
}

# Get a channel mode from its name
sub get_channel_mode_from_name {
    my ($irc, $name) = &args;
    return (grep { lc $_->{name} eq lc $name } values %{$irc->{channel_modes}})[0];
}

# Get a channel mode from its letter
sub get_channel_mode_from_letter {
    my ($irc, $letter) = &args;
    return (grep { $_->{letter} eq $letter } values %{$irc->{channel_modes}})[0];
}

# Get a channel mode from its symbol
sub get_channel_mode_from_symbol {
    my ($irc, $sym) = &args;
    foreach my $mode (values %{$irc->{channel_modes}}) {
        next unless defined $mode->{symbol};
        return $mode if $mode->{symbol} eq $sym;
    }
    return;
}

# Create a new user IRC::Mode and add it to this IRC instance
sub create_user_mode {
    my ($irc, %opts) = &args;
    my $mode = IRC::Mode->new(%opts) or return;
    $irc->add_user_mode($mode);
    return $mode;
}

# Add a channel IRC::Mode to this IRC instance
sub add_user_mode {
    my ($irc, $mode) = &args;
    return if !$mode->isa('IRC::Mode');
    $irc->{user_modes}->{$mode->{name}} = $mode;
}

# Get a user mode from its name
sub get_user_mode_from_name {
    my ($irc, $name) = &args;
    return (grep { lc $_->{name} eq lc $name } values %{$irc->{user_modes}})[0];
}

# Get a user mode from its letter
sub get_user_mode_from_letter {
    my ($irc, $letter) = &args;
    return (grep { $_->{letter} eq $letter } values %{$irc->{user_modes}})[0];
}

# Returns an array of actual users (not services)
sub users {
    my $irc = &args;
    return grep { !$_->is_service } values %{$irc->{users}};
}

# Returns an array of services
sub services {
    my $irc = &args;
    return grep { $_->is_service } values %{$irc->{users}};
}

sub args {
    my $on = shift;
    $on    = $IRC::irc if $on eq 'IRC';
    return ($on, @_);
}

1;

# vim: set ai et sw=4 ts=4:

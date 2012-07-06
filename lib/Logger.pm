# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package Logger;

use warnings;
use strict;
use base 'EventedObject';

# create a new Logger object with default classes.
sub new {
    bless { classes => {
        INFO => [qw(
            MODINIT_INFO MODLOAD_INFO CONF_INFO SOCKET_INFO
            TIMER_INFO
        )],
        ERROR => [qw(
            FATAL MODINIT_ERROR MODLOAD_ERROR CONF_ERROR
            SOCKET_ERROR CHANNEL_ERROR USER_ERROR
            SERVER_ERROR TIMER_ERROR DATABASE_ERROR
        )],
        MODULES => [qw(
            MODINIT_INFO MODLOAD_INFO MODINIT_ERROR
            MODLOAD_ERROR
        )],
        SOCKETS => [qw(
            SOCKET_ERROR SOCKET_INFO
        )]
    } }, shift;
}

sub log {
    my ($self, $level, $message) = @_;;
    my $caller = caller 0;
    $self->fire("LOG_$level" => $message, $caller);
    $self->fire(LOG_ALL      => $message, $caller);

    # fire events for each class this level belongs to.
    foreach my $class (keys %{$self->{classes}}) {
        if ($level ~~ @{$self->{classes}->{$class}}) {
            $self->fire("LOG_$class" => $message, $caller);
        }
    }

    return 1;
}

# add a logging level to a class.
sub add_to_class {
    my ($self, $level, $class) = @_;
    $self->{classes}->{$class} ||= [];
    push @{$self->{classes}->{$class}}, $level;
}

1;

# vim: set ai et sw=4 ts=4:

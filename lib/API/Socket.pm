# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package API::Socket;

use warnings;
use strict;
use base qw(IO::Async::Stream EventedObject);
use 5.010;

sub new {
    my ($class, $mod, %opts) = (shift, @_);

    # Make sure all required options are present
    foreach my $what (qw|name address port|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        $::logger->log(SOCKET_ERROR => "Socket $opts{name} does not have '$what' option.");
        return;
    }

    # create the actual socket, IO::Socket::IP.
    my $socket = IO::Socket::IP->new(
        PeerAddr => $opts{address},
        PeerPort => $opts{port},
        Proto    => $opts{proto} || 'tcp'
    ) or $::logger->log(SOCKET_ERROR => "Socket $opts{name} failed to connect.") and return;

    # create an IO::Async::Stream.
    my $self;
    $self = $class->SUPER::new(
        handle  => $socket,
        on_read => sub {
            my (undef, $buffref, $eof) = @_;
            while ($$buffref =~ s/^(.*\n)//) {
                $self->fire(got_line => $1);
            }
        },
        on_read_eof => sub {
            $::logger->log(SOCKET_INFO => "Socket $opts{name}: got read EOF");
            $self->fire('read_eof');
        },
        on_write_eof => sub {
            $::logger->log(SOCKET_INFO => "Socket $opts{name}: got write EOF");
            $self->fire('write_eof');
        },
        on_read_error => sub {
            $::logger->log(SOCKET_ERROR => "Socket $opts{name}: a read error occured");
            $self->fire('read_error');
        },
        on_write_error => sub {
            $::logger->log(SOCKET_ERROR => "Socket $opts{name}: a write error occured");
            $self->fire('write_error');
        }
    );

    $self->{name} = $opts{name};
    $::logger->log(SOCKET_INFO => "Socket $opts{name} has been established.");
    return $self;
}

# connect
sub go {
    my $sock = shift;
    $main::loop->add($sock);
    $::logger->log(SOCKET_INFO => "Socket $$sock{name} connected.");
}

1;

# vim: set ai et sw=4 ts=4:

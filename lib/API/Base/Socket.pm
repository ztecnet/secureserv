# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package API::Base::Socket;

use warnings;
use strict;

use API::Socket;

sub create_socket {
    my $mod    = shift;
    my $socket = API::Socket->new($mod, @_) or return;
    $mod->{sockets} ||= [];
    push @{$mod->{sockets}}, $socket;
    return $socket;
}

# close any running sockets.
sub unload {
    my ($class, $mod) = @_;
    return 1 unless $mod->{sockets}; # none
    $_->close_when_empty foreach @{$mod->{sockets}};
    return 1;
}

1;

# vim: set ai et sw=4 ts=4:

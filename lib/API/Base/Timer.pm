# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package API::Base::Timer;

use warnings;
use strict;

use API::Timer;

sub create_timer {
    my $mod    = shift;
    my $timer  = API::Timer->new($mod, @_) or return;
    $mod->{timers} ||= [];
    push @{$mod->{timers}}, $timer;
    return $timer;
}

# delete any running timers.
sub unload {
    my ($class, $mod) = @_;
    return 1 unless $mod->{timers}; # none
    $_->stop foreach @{$mod->{timers}};
    return 1;
}

sub delete_timer {
    my ($class, $mod, $timer) = @_;
    return 1 unless $mod->{timers}; # none
    $timer->stop;
    @{$mod->{timers}} = grep { $_ != $timer } @{$mod->{timers}};
    return 1;
}

1;

# vim: set ai et sw=4 ts=4:

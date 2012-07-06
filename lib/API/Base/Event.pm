# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package API::Base::Event;
 
use warnings;
use strict;

# Bind/Create a event.
sub bind_event {
    my ($mod, $event, $handler, $name) = @_;
    $mod->{hooks} ||= [];
    $main::proto->event->on($event => $handler, $name);
    my %opts = (event => $event, name => $name);
    push @{$mod->{hooks}}, \%opts;
    return 1;
}

# Unbind/Delete a registered event.
sub unbind_event {
    my ($mod, $name) = @_;
    my @matches = grep { uc($_->{name}) eq uc($name) } values %{$mod->{hooks}};
    foreach (@matches) {
        $main::proto->event->del($_->{event} => $_->{name});
    }
    return 1;
}

# Remove all registered events.
sub unload {
    my $mod = shift;
    $main::proto->event->del($_->{event} => $_->{name}) foreach @{$mod->{hooks}};
    delete $mod->{hooks};
    return 1;
}

1;

# vim: set ai et sw=4 ts=4:

# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package API::Base::Service;
 
use warnings;
use strict;

sub create_service {
    my ($mod, %opts) = @_;
    my $service = IRC->create_service(%opts) or return;
    $mod->{services} ||= [];
    push @{$mod->{services}}, $service;
    return $service;
}

# Remove all registered services
sub unload {
    my $mod = shift;
    IRC->delete_user($_) foreach @{$mod->{services}};
    delete $mod->{services};
    return 1;
}

1;

# vim: set ai et sw=4 ts=4:

# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package API::Base::Command;
 
use warnings;
use strict;

# Bind/Create a command.
sub bind_command {
    my ($mod, %opts) = @_;
    $opts{priv} ||= 'any';
    foreach my $what (qw|name handler|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        $mod->log(COMMAND_ERROR => "Refusing to create command $opts{name} because it's missing the '$what' parameter.");
        return;
    }
    $opts{name} = uc($opts{name});
    $opts{event} ||= 'cmd_'.$opts{name};
    $opts{eventname} ||= 'cmd.'.lc($opts{name});
    $mod::svs->on($opts{event} => $opts{handler}, $opts{eventname});
    $mod->{commands} ||= [];
    push @{$mod->{commands}}, \%opts;
    return 1;
}

# Unbind/Delete a registered command.
sub unbind_command {
    my ($mod, $command) = @_;
    my @matches = grep { $_->{name} eq uc($command) } values %{$mod->{commands}};
    foreach (@matches) {
        $mod::svs->del($_->{event} => $_->{eventname});
    }
    return 1;
}

# Remove all registered commands
sub unload {
    my $mod = shift;
    $mod::svs->del($_->{event} => $_->{eventname}) foreach @{$mod->{commands}};
    delete $mod->{commands};
    return 1;
}

1;

# vim: set ai et sw=4 ts=4:

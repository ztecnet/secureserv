# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::operserv::uptime;

use strict;
use warnings;
use 5.010;

our $svs;

our $mod = API::Module->new(
    name         => 'operserv/uptime',
    version      => '1.0',
    description  => 'Creates UPTIME command.',
    requirements => ['Logger', 'Command'],
    dependencies => ['operserv/main'], 
    initialize   => \&init,
    void         => \&void
);

sub init {
    $mod::svs = $svs = IRC->get_service('operserv');
    # Sanity checking.
    $mod->log(MODLOAD_ERROR => 'Refusing to load. Operator service could not be found.') and return if !$svs;
    # Create bindings.
    $mod->bind_command(
        name        => 'UPTIME',
        description => 'Responds with services uptime.',
        helpfile    => 'operserv/uptime',
        handler     => \&cmd_uptime
    );
    # We're good.
    return 1;
}

sub void {
    return 1;
}

sub cmd_uptime {
    my $user = shift;
    my ($started, $days, $hours, $minutes) = Utils::get_uptime();
    $svs->notice($user, "Services were started on $started. They have been up for $days days, $hours hours, and $minutes minutes.");
}

$mod;

# vim: set ai et sw=4 ts=4:

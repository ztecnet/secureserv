# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::chanserv::ping;

use strict;
use warnings;
use 5.010;

our $svs;

our $mod = API::Module->new(
    name         => 'chanserv/ping',
    version      => '1.0',
    description  => 'Creates PING command.',
    requirements => ['Logger', 'Command'],
    dependencies => ['chanserv/main'], 
    initialize   => \&init,
    void         => \&void
);

sub init {
    $mod::svs = $svs = IRC->get_service('chanserv');
    # Sanity checking.
    $mod->log(MODLOAD_ERROR => 'Refusing to load. Channel service could not be found.') and return if !$svs;
    # Create bindings.
    $mod->bind_command(
        name        => 'PING',
        description => 'Responds with Pong!',
        helpfile    => 'chanserv/ping',
        handler     => \&cmd_ping
    );
    # We're good.
    return 1;
}

sub void {
    return 1;
}

sub cmd_ping { $svs->notice(shift, 'Pong!'); }

$mod;

# vim: set ai et sw=4 ts=4:

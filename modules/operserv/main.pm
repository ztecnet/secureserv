# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::operserv::main;

use strict;
use warnings;
use 5.010;

our ($proto, $svs);

our $mod = API::Module->new(
    name         => 'operserv/main',
    version      => '1.0',
    description  => 'Creates operserv client.',
    requirements => ['Logger', 'Service'],
    dependencies => [], 
    initialize   => \&init
);

sub init {
    
    # Do config checks.
    foreach my $what (qw|nick user host gecos|) {
        if (!$::conf->get("service:operserv:$what")) {
            $mod->log(MODLOAD_ERROR => "Refusing to load. Missing 'service:operserv:$what' in configuration.");
            return;
        }
    }

    $svs = $mod->create_service(
        nick    => $::conf->get('service:operserv:nick'),
        ident   => $::conf->get('service:operserv:user'),
        host    => $::conf->get('service:operserv:host'),
        gecos   => $::conf->get('service:operserv:gecos'),
        service => 'operserv'
    );

    $main::proto->on(burst_end => sub { $svs->join_logchans; }, 'os.joinlogchans');
    
    return 1;
}

$mod;

# vim: set ai et sw=4 ts=4:

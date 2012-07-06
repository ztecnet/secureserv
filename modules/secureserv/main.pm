# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::secureserv::main;

use strict;
use warnings;
use 5.010;

our ($proto, $svs);

our $mod = API::Module->new(
    name         => 'secureserv/main',
    version      => '1.0',
    description  => 'Creates sercureserv client.',
    requirements => ['Logger', 'Service'],
    dependencies => [], 
    initialize   => \&init
);

sub init {
    
    # Do config checks.
    foreach my $what (qw|nick user host gecos|) {
        if (!$::conf->get("service:secureserv:$what")) {
            $mod->log(MODLOAD_ERROR => "Refusing to load. Missing 'service:operserv:$what' in configuration.");
            return;
        }
    }

    $svs = $mod->create_service(
        nick    => $::conf->get('service:secureserv:nick'),
        ident   => $::conf->get('service:secureserv:user'),
        host    => $::conf->get('service:secureserv:host'),
        gecos   => $::conf->get('service:secureserv:gecos'),
        service => 'secureserv'
    );

    $main::proto->on(burst_end => sub { $svs->join_logchans; }, 'ss.joinlogchans');
    
    return 1;
}

$mod;

# vim: set ai et sw=4 ts=4:

# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::logserv::main;

use strict;
use warnings;
use 5.010;

our ($proto, $svs);

our $mod = API::Module->new(
    name         => 'logserv/main',
    version      => '1.0',
    description  => 'Creates logserv client.',
    requirements => ['Logger', 'Service'],
    dependencies => [], 
    initialize   => \&init
);

sub init {
    
    # Do config checks.
    foreach my $what (qw|nick user host gecos|) {
        if (!$::conf->get("service:logserv:$what")) {
            $mod->log(MODLOAD_ERROR => "Refusing to load. Missing 'service:logserv:$what' in configuration.");
            return;
        }
    }

    # Create service.
    $svs = $mod->create_service(
        nick    => $::conf->get('service:logserv:nick'),
        ident   => $::conf->get('service:logserv:user'),
        host    => $::conf->get('service:logserv:host'),
        gecos   => $::conf->get('service:logserv:gecos'),
        service => 'logserv'
    );

    $main::proto->on(burst_end => sub { $svs->join_logchans; }, 'ls.joinlogchans');
    
    return 1;
}

$mod;

# vim: set ai et sw=4 ts=4:

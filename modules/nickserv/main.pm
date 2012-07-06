# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::nickserv::main;

use strict;
use warnings;
use 5.010;

our ($proto, $svs);

our $mod = API::Module->new(
    name         => 'nickserv/main',
    version      => '1.0',
    description  => 'Creates nickserv client.',
    requirements => ['Logger', 'Service'],
    dependencies => [], 
    initialize   => \&init
);

sub init {
    
    # Do config checks.
    foreach my $what (qw|nick user host gecos|) {
        if (!$::conf->get("service:nickserv:$what")) {
            $mod->log(MODLOAD_ERROR => "Refusing to load. Missing 'service:nickserv:$what' in configuration.");
            return;
        }
    }

    $svs = $mod->create_service(
        nick    => $::conf->get('service:nickserv:nick'),
        ident   => $::conf->get('service:nickserv:user'),
        host    => $::conf->get('service:nickserv:host'),
        gecos   => $::conf->get('service:nickserv:gecos'),
        service => 'nickserv'
    );

    $main::proto->on(burst_end => sub { $svs->join_logchans; }, 'ns.joinlogchans');
    
    return 1;
}

$mod;

# vim: set ai et sw=4 ts=4:

# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::chanserv::main;

use strict;
use warnings;
use 5.010;

our ($proto, $svs);

our $mod = API::Module->new(
    name         => 'chanserv/main',
    version      => '1.0',
    description  => 'Creates chanserv client.',
    requirements => ['Logger', 'Service'],
    dependencies => [], 
    initialize   => \&init
);

sub init {
    
    # Do config checks.
    foreach my $what (qw|nick user host gecos|) {
        if (!$::conf->get("service:chanserv:$what")) {
            $mod->log(MODLOAD_ERROR => "Refusing to load. Missing 'service:chanserv:$what' in configuration.");
            return;
        }
    }

    $svs = $mod->create_service(
        nick    => $::conf->get('service:chanserv:nick'),
        ident   => $::conf->get('service:chanserv:user'),
        host    => $::conf->get('service:chanserv:host'),
        gecos   => $::conf->get('service:chanserv:gecos'),
        service => 'chanserv'
    );
    
    $svs->on(cmd => sub {
        my ($cmd, $user) = @_;
        # Return if the command exists.
        return if $svs->has_command($cmd);
        # Otherwise tell the user it doesn't exist.
        # Really we need to make $svs->notice or $svs->reply to follow the API/allow for non-uid using protocols.
        $svs->send('NOTICE '.$user->id.' :Unknown command.');
    }, 'check.cmd');

    $main::proto->on(burst_end => sub { $svs->join_logchans; }, 'cs.joinlogchans');
    
    return 1;
}

$mod;

# vim: set ai et sw=4 ts=4:

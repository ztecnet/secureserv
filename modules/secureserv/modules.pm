# Copyright 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::secureserv::modules;

use strict;
use warnings;
use 5.010;

our $svs;

our $mod = API::Module->new(
    name         => 'secureserv/modules',
    version      => '1.0',
    description  => 'Creates commands useful for managing modules.',
    requirements => ['Logger', 'Command'],
    dependencies => ['secureserv/main'], 
    initialize   => \&init,
    void         => \&void
);

sub init {
    $mod::svs = $svs = IRC->get_service('secureserv');
    # Sanity checking.
    $mod->log(MODLOAD_ERROR => 'Refusing to load. Security service could not be found.') and return if !$svs;
    # Create bindings.
    $mod->bind_command(
        name        => 'MODLOAD',
        description => 'Loads a module.',
        helpfile    => 'secureserv/modload',
        handler     => \&cmd_modload
    );
    $mod->bind_command(
        name        => 'MODUNLOAD',
        description => 'Unloads a module.',
        helpfile    => 'secureserv/modunload',
        handler     => \&cmd_modunload
    );
    $mod->bind_command(
        name        => 'MODRELOAD',
        description => 'Reloads a module.',
        helpfile    => 'secureserv/modreload',
        handler     => \&cmd_modreload
    );
    # Create modload loading error hook.
    $::logger->on(LOG_MODLOAD_ERROR => \&mod_error, 'secureserv.moderr_log');
    # " " info hook.
    $::logger->on(LOG_MODLOAD_INFO => \&mod_info, 'secureserv.modinfo_log');
    # We're good.
    return 1;
}

sub void {
    $::logger->del(LOG_MODLOAD_ERROR => 'secureserv.moderr_log');
    $::logger->del(LOG_MODLOAD_INFO => 'secureserv.modinfo_log');
    return 1;
}

sub cmd_modload {
    my ($user, @args) = @_;
    if (!@args) { $svs->notice($user, "Missing parameters. \2Syntax:\2 MODLOAD <module>"); return; }
    if (API::is_loaded($args[0])) { $svs->notice($user, "Module \2$args[0]\2 is already loaded."); return; }
    my $load = API::load_module($args[0], "$args[0].pm");
    unless ($load ne 1) {
        $svs->notice($user, "Successfully loaded \2$args[0]\2.");
    }
    else {
        $svs->notice($user, "Error while loading \2$args[0]\2: $load");
    }
}

sub cmd_modunload {
    my ($user, @args) = @_;
    if (!@args) { $svs->notice($user, "Missing parameters. \2Syntax:\2 MODUNLOAD <module>"); return; }
    if (!API::is_loaded($args[0])) { $svs->notice($user, "Module \2$args[0]\2 isn't loaded."); return; }
    my $unload = API::unload_module($args[0], "$args[0].pm");
    unless ($unload ne 1) {
        $svs->notice($user, "Successfully unloaded \2$args[0]\2.");
    }
    else {
        $svs->notice($user, "Error while unloading \2$args[0]\2: $unload");
    }
}

sub cmd_modreload {
    my ($user, @args) = @_;
    if (!@args) { $svs->notice($user, "Missing parameters. \2Syntax:\2 MODRELOAD <module>"); return; }
    if (!API::is_loaded($args[0])) { $svs->notice($user, "Module \2$args[0]\2 isn't loaded."); return; }
    my $step = API::unload_module($args[0], "$args[0].pm");
    $svs->notice($user, "Error while unloading \2$args[0]\2: $step") and return if $step ne 1;
    $step = API::load_module($args[0], "$args[0].pm");
    $svs->notice($user, "Error while loading \2$args[0]\2: $step") and return if $step ne 1;
    $svs->notice($user, "Successfully reloaded \2$args[0]\2");
}


sub mod_error {
    $svs->logchan($_[0]) if $main::proto::synced;
}
sub mod_info { $svs->logchan($_[0]) if $main::proto::synced; }

$mod;

# vim: set ai et sw=4 ts=4:

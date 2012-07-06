# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package API;

use warnings;
use strict;
use 5.010;

use API::Module;

our (@load_conf, @loaded);

# load modules in the configuration.
sub load_config {
    $::logger->log(MODLOAD_INFO => 'Loading modules in configuration.');
    load_module($_, "$_.pm") foreach @load_conf;
    $::logger->log(MODLOAD_INFO => 'Done loading modules in configuration.');
    undef @load_conf;
}

sub load_module {
    my $name = shift;

    # has this module been loaded already?
    foreach my $mod (@loaded) {
        next if lc $mod->{name} ne lc $name;
        $::logger->log(MODLOAD_ERROR => "Module $name is already loaded.");
        return;
    }

    # load the module.
    my $file   = q(modules/).shift();
    my $module = do $file or $::logger->log(MODLOAD_ERROR => "Couldn't load $file: ".($@ ? $@ : $!)) and return;

    # Make sure it returned properly. Even though this is unsupported nowadays, it is
    # still the easiest way to prevent a fatal error.
    if (!UNIVERSAL::isa($module, 'API::Module')) {
        $::logger->log(MODLOAD_ERROR => "Module $name did not return an API::Module object.");
        return
    }

    # second check that the module doesn't exist already.
    # We really should check this earlier as well, seeing as subroutines and other symbols
    # could have been changed beforehand. This is just a double check.
    foreach my $mod (@loaded) {
        next unless $mod->{package} eq $module->{package};
        $::logger->log(MODLOAD_ERROR => "Module $name seems to already be loaded.");
        return
    }

    # load the requirements if they are not already.
    load_requirements($module) && check_dependencies($module) or
    $::logger->log(MODLOAD_ERROR => "Could not satisfy dependencies of $name") and return;

    # initialize the module.
    $::logger->log(MODLOAD_INFO => "Initializing module $$module{name}");
    $module->{initialize}->() or $::logger->log(MODLOAD_ERROR => "Module $name refused to load.") and return;

    $::logger->log(MODLOAD_INFO => "Module $name loaded successfully");
    push @loaded, $module;

    return 1;
}

sub unload_module {
    my ($name, $file, $mod) = @_;

    # find it..
    foreach my $module (@loaded) {
        next unless lc $module->{name} eq lc $name;
        $mod = $module;
        last
    }

    # is it even loaded?
    if (!$mod) {
        $::logger->log(MODLOAD_ERROR => "Can't unload $name because it isn't loaded.");
        return;
    }

    # ensure that no other modules depend on it.
    foreach my $module (@loaded) {
        next unless $mod->{name} ~~ @{$module->{dependencies}};
        $::logger->log(MODLOAD_ERROR => "Can't unload $name because other modules depend on it.");
        return;
    }

    # unload all of its commands, loops, modes, etc.
    call_unloads($mod);

    # unload package to free memory.
    class_unload($mod->{package});

    @loaded = grep { $_ != $mod } @loaded;

    # call void if exists.
    if ($mod->{void}) {
        $mod->{void}->()
        or $::logger->log(MODLOAD_ERROR => "Can't unload $name because it refuses.")
        and return;
    }

    return 1
}

# Load BASES, not dependencies.
sub load_requirements {
    my $mod = shift;
    return unless ref $mod->{requirements};
    return if ref $mod->{requirements} ne 'ARRAY';
    load_base($_) foreach @{$mod->{requirements}};
    return 1
}

sub load_base {
    my $base = shift;

    # is this base already loaded?
    return 1 if $INC{"API/Base/$base.pm"};

    $::logger->log(MODLOAD_INFO => "Loading base $base");
    require "API/Base/$base.pm" or $::logger->log(MODLOAD_ERROR => "Could not load base $base.") and return;

    # make API::Module inherit from it.
    unshift @API::Module::ISA, "API::Base::$base";

    return 1
}

# check that required modules are loaded.
sub check_dependencies {
    my $mod = shift;
    return 1 if (!$mod->{dependencies} or ref $mod->{dependencies} ne 'ARRAY');
    foreach (@{$mod->{dependencies}}) { return unless is_loaded($_) }
    return 1;
}

# inform each API::Base of the unload.
sub call_unloads {
    my $module = shift;
    $_->unload($module) foreach @API::Module::ISA;
}

# Delete an entire package.
sub class_unload {
    my $class = shift;
    no strict 'refs';

    @{$class.'::ISA'} = ();
    my $symtab = $class.'::';

    # delete all symbols except other tables
    for my $symbol (keys %$symtab) {
        next if $symbol =~ m/\A[^:]+::\z/;
        delete $symtab->{$symbol};
    }

    my $inc_file = join('/', split /(?:'|::)/, $class).q(.pm);
    delete $INC{$inc_file};

    return 1
}

# see if a module is loaded (by name).
sub is_loaded {
    my $name = shift;
    return grep { $_->{name} == $name } @loaded;
}

1;

# vim: set ai et sw=4 ts=4:

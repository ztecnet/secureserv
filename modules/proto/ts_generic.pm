# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::proto::ts_generic;

use strict;
use warnings;
use 5.010;

our $mod = my $proto = API::Module->new(
    name         => 'proto/ts_generic',
    version      => '1.0',
    description  => 'Adds generic TS functions.',
    requirements => [],
    dependencies => [],
    initialize   => \&init,
    void         => sub { return; } # Refuse to allow unloading this module.
);

# Create a variable for our last UID.
our $lastid = 'AAAAAA';
	
sub init {
    # We can't really provide our functions without a proper SID.
    return if !$::conf->get('me:sid');
    return if length($::conf->get('me:sid')) != 3;
    # We're good.
    return 1;
}

sub gen_uid {
    return $::conf->get('me:sid').$lastid++;
}

$mod;

# vim: set ai et sw=4 ts=4:

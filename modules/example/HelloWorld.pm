# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::example::HelloWorld;

our $mod = API::Module->new(
    name         => 'example/HelloWorld',
    version      => '1.0',
    description  => 'Hello World!',
    requirements => ['Logger'],
    initialize   => \&init,
    void         => \&void
);

sub init {
    $mod->log(INFO => 'Hello World!');
    return 1;
}

sub void {
    $mod->log(INFO => 'Goodbye World!');
    return 1;
}

$mod;

# vim: set ai et sw=4 ts=4:

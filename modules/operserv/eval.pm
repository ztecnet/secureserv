# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::operserv::eval;

use strict;
use warnings;
use 5.010;

our $svs;

our $mod = API::Module->new(
    name         => 'operserv/eval',
    version      => '1.0',
    description  => 'Creates EVAL command.',
    requirements => ['Logger', 'Command'],
    dependencies => ['operserv/main'], 
    initialize   => \&init,
    void         => \&void
);

sub init {
    $mod::svs = $svs = IRC->get_service('operserv');
    # Sanity checking.
    $mod->log(MODLOAD_ERROR => 'Refusing to load. Operator service could not be found.') and return if !$svs;
    # Create bindings.
    $mod->bind_command(
        name        => 'EVAL',
        description => 'Responds with result of evaluated perl code.',
        helpfile    => 'operserv/eval',
        handler     => \&cmd_eval
    );
    # We're good.
    return 1;
}

sub void {
    return 1;
}

sub cmd_eval {
    my ($user, @args) = @_;
    $svs->notice($user, "Invalid arguments. \2Syntax:\2 EVAL <expression>") and return if !@args;
    my $expr = join ' ', @args;
    my $result = do {
        local $SIG{__WARN__} = sub {
            my $msg = shift;
            chomp $msg; $svs->notice($user, "Warning: $msg");
        };
        local $SIG{__DIE__} = sub {
            my $msg = shift;
            chomp $msg; $svs->notice($user, "Error: $msg");
        };
        eval $expr;
    };

    if (!defined $result) { $result = "undef"; }
    my @lines = split("\n", $result);
    $svs->notice($user, "Output: $_") foreach @lines;
}

$mod;

# vim: set ai et sw=4 ts=4:

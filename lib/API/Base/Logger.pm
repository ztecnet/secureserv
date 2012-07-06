# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package API::Base::Logger;

use warnings;
use strict;

sub log {
    my ($mod, $level, $message) = @_;
    $main::logger->log($level => "[$$mod{name}:$$mod{version}] $message");
}

sub unload {
    return 1;
}

# add a logging level to a class.
sub add_to_log_class {
    my $mod = shift;
    $main::logger->add_to_class(@_);
}

1;

# vim: set ai et sw=4 ts=4:

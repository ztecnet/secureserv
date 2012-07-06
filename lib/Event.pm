# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package Event;

use warnings;
use strict;
use base 'EventedObject';

sub new {
    my $class = shift;
    return bless my $event = {}, $class;
}

1;
 
# vim: set ai et sw=4 ts=4:

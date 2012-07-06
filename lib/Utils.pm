# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package Utils;

use warnings;
use strict;
use 5.010;

# Remove prefixing colon.
sub col {
    my $string = shift;
    $string =~ s/^://;
    return $string;
}

# Check if an element is in an array.
sub in_array {
    my ($element, @array) = @_;
    return 1 if grep $_ eq $element, @array;
    return 0;
}

# Get services uptime.
sub get_uptime {
    my $uptime = time() - $^T;
    my $minutes = 0;
    my $hours = 0;
    my $days = 0;
    while ($uptime >= 60) {
        $uptime = $uptime - 60;
        $minutes = $minutes + 1;
    }
    while ($minutes >= 60) {
        $minutes = $minutes - 60;
        $hours = $hours + 1;
    }
    while ($hours >= 24) {
        $hours = $hours - 24;
        $days = $days + 1;
    }
    return (scalar(localtime($^T)), $days, $hours, $minutes);
}

1;

# vim: set ai et sw=4 ts=4:


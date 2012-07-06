# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package IRC::Mode;

use warnings;
use strict;
use 5.010;

use Attributes qw(name letter type kind symbol);

# Mode types:
#     0: plain old mode that can be set and unset                      (ex. channel protect topic)
#     1: mode that takes a parameter always                            (ex. channel key)
#     2: mode that takes a parameter only when set                     (ex. channel limit)
#     3: mode that always takes a parameter and modifies a list        (ex. channel ban)
#     4: mode that always takes a parameter and modifies a status list (ex. channel op)

sub new {
    my ($class, %opts) = @_;

    # Make sure all required options are present
    foreach my $what (qw|name letter type kind|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        $::logger->log(MODE_ERROR => "Mode $opts{name} does not have '$what' option.");
        return;
    }

    # Ensure that 'type' is valid.
    if (not $opts{type} ~~ [0..4]) {
        $::logger->log(MODE_ERROR => "Mode $opts{name} has an invalid type $opts{type}.");
    }

    return bless \%opts, $class;
}

sub needs_param {
    return do { given (shift->{type}) {
        when ([0])       { 'never'     }
        when ([1, 3, 4]) { 'always'    }
        when ([2])       { 'sometimes' }
    } };
}

sub is_cmode { shift->{kind} eq 'channel' }
sub is_umode { shift->{kind} eq 'user'    }

1;
 
# vim: set ai et sw=4 ts=4:

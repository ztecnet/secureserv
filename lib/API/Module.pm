# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package API::Module;

use warnings;
use strict;
use Attributes qw(name description version);

our @ISA;

sub new {

    my ($class, %opts) = @_;
    $opts{requirements}  ||= [];
    $opts{dependencies}  ||= [];

    # Make sure all required options are present
    foreach my $what (qw|name version description|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        $::logger->log(MODINIT_ERROR => "Module $opts{name} does not have '$what' option.");
        return;
    }

    # Initialize and void must be a CODE ref.
    if ((defined $opts{initalize}) && (not defined ref $opts{initialize} or ref $opts{initalize} ne 'CODE')) {
        $::logger->log(MODINIT_ERROR => "Module $opts{name} provided initialize, but it is not a CODE ref.");
        return;
    }
    if ((defined $opts{void}) && (not defined ref $opts{void} or ref $opts{void} ne 'CODE')) {
        $::logger->log(MODINIT_ERROR => "Module $opts{name} provided void, but it is not a CODE ref.");
        return;
    }

    # Package name
    $opts{package} = caller;

    return bless my $mod = \%opts, $class;

}

1;

# vim: set ai et sw=4 ts=4:


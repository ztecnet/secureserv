# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package IRC::Server;

use warnings;
use strict;
use base 'EventedObject';
use Attributes qw(parent name sid description);

sub new {
    my ($class, %opts) = @_;
    
    # Make sure all required options are present
    foreach my $what (qw|parent name sid description|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        $::logger->log(SERVER_ERROR => "Server $opts{name} does not have '$what' option.");
        return;
    }
    
    return bless my $server = \%opts, $class;
}
 
1;
 
# vim: set ai et sw=4 ts=4:

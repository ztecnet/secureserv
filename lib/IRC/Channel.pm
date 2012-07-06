# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package IRC::Channel;

use warnings;
use strict;
use base 'EventedObject';
use Attributes qw(name ts modes users topic topicts);

sub new {
    my ($class, %opts) = @_;
    $opts{users} ||= [];
    
    # Make sure all required options are present
    foreach my $what (qw|name ts modes users|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        $::logger->log(CHANNEL_ERROR => "Channel $opts{name} does not have '$what' option.");
        return;
    }
    
    return bless my $channel = \%opts, $class;
}
 
1;
 
# vim: set ai et sw=4 ts=4:

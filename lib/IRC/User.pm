# Copyright (c) 2012 Arinity
# # see doc/LICENSE for license information.
package IRC::User;

use warnings;
use strict;
use base 'EventedObject';
use Attributes qw(nick ident mask gecos host ip ts server modes uid channels);

sub new {
    my ($class, %opts) = @_;
    $opts{channels} ||= [];
    
    # Make sure all required options are present
    foreach my $what (qw|nick ident mask gecos host ip ts server modes uid|) {
        next if exists $opts{$what};
        $opts{nick} ||= 'unknown';
        $::logger->log(USER_ERROR => "User $opts{nick} does not have '$what' option.");
        return;
    }
    
    return bless my $user = \%opts, $class;
}
 
1;
 
# vim: set ai et sw=4 ts=4:

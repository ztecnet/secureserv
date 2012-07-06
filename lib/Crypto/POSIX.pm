# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package Crypto::POSIX;

use strict;
use warnings;

sub new {
     bless { }, shift;
}

sub rand_string {
    my ($self, $length) = @_;
	my $string;
	my @chars = ('a' .. 'z');
	
	foreach (1..$length) {
	    $string .= $chars[rand @chars];
	}
	
	return $string;
}

sub generate_salt {
    my $self = shift;
    return '$1$'.$self->rand_string(6).'$';
}

sub encrypt {
    my ($self, $pass) = @_;
    return crypt($pass, $self->generate_salt());
}

1;

# vim: set ai et sw=4 ts=4:

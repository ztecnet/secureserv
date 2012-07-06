# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package Attributes;

use warnings;
use strict;
use 5.010;

sub import {
    my $package = caller;
    no strict 'refs';
    foreach my $sym (@_[1..$#_]) {
        my $name = $sym;

        # this is quite ugly, but it's the only way to do it for compatibility with perl 5.12
        my $code = do { given (substr $name, 0, 1) {

            # arrays
            when ('@') { $name = substr $name, 1; sub {
                my $self = shift;
                if ($self->{$name} && ref $self->{$name} eq 'ARRAY') {
                    return @{$self->{$name}};
                }
                # empty array
                my @a;
                $self->{$name} = \@a;
                @a;
            } }

            # hashes
            when ('%') { $name = substr $name, 1; sub {
                my $self = shift;
                if ($self->{$name} && ref $self->{$name} eq 'HASH') {
                    return %{$self->{$name}};
                }
                # empty hash
                my %h;
                $self->{$name} = \%h;
                %h;
            } }

            # plain old value
            default { sub {
                shift->{$name};
            } }

        } };
        *{$package.q(::).$name} = $code;
    }
}

1;

# vim: set ai et sw=4 ts=4:

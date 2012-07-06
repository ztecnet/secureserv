# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package Conf;

use warnings;
use strict;
use feature 'switch';

use base 'EventedObject';
use Attributes qw(file config);

# Create a new Config instance.
sub new {
    my ($self, $file) = @_;
    return unless defined $file;
    bless { file => $file, config => {}, }, $self;
}

sub parse {
    my $self = shift;
    delete $self->{parsed};
    if (!-e $self->file) {
        $::logger->log(CONF_ERROR => "*** Configuration file (".$self->file.") not found...");
        return;
    }
    if (!-r $self->file) {
        $::logger->log(CONF_ERROR => "*** Configuration file (".$self->file.") not readable...");
        return;
    }

    open my $fh, '<'.$self->file or $::logger->log(CONF_ERROR => $!) and return;
    my ($i, $block, $name, $key, $val, %conf) = (0, 'sec', 'main');

    LINE: for (<$fh>) {
        $i++;

        # named block start
        # block "name" {
        when (/^(.+?)\s*"(.+?)"\s*{/) {
            ($block, $name) = (trim($1), trim($2));
        }

        # nameless block start
        # block {
        when (/^(.+?)\s*{/) {
            ($block, $name) = ('sec', trim($1));
        }

        # key & value
        when (/^(.+?)\s*=(.+)/) {
            $conf{$block}{$name}{trim($1)} = parse_value(trim($2));
        }

        # closing bracket
        when (/^}/) {
            undef $block;
            undef $name;
        }

        # function
        when (/^(.+?) (.+)/) {
            $self->fire('function_'.trim($1) => $block, $name, parse_value(trim($2)));
        }

        # comment

        when (/^#/) {
            next LINE;
        }
    }

    close $fh;
    $self->{config} = \%conf;
    $self->{parsed} = 1;
    return $self;
}

# get conf value
# example: me:name
# example: service:nickserv:gecos
sub get {
    my ($self, $str)      = @_;
    my ($current, $level) = $self->config;
    my @levels = split /:/, $str;

    # unnamed block
    unshift @levels, 'sec' if scalar @levels == 2;

    while (defined ( $level = shift @levels )) {
        $current = $current->{$level}
    }
    return make_value_useful($current);
}

# (actual get) same as get but does not assume what you mean for convenience.
sub aget {
    my ($self, $str)      = @_;
    my ($current, $level) = $self->config;
    my @levels = split /:/, $str;

    while (defined ( $level = shift @levels )) {
        return unless ref $current eq 'HASH';
        $current = $current->{$level};
    }
    return make_value_useful($current);
}

# (long get) same as get but accepts separate arguments
# (useful for fetching conf values from variables)
sub lget {
    my ($self, @levels) = @_;
    my ($current, $level) = $self->config;
    while (defined ( $level = shift @levels )) {
        return unless ref $current eq 'HASH';
        $current = $current->{$level};
    }
    return make_value_useful($current);
}

sub parse_value {
    my $value = shift;
    given ($value) {
        # string
        when (/"(.+)"/) {
            return $1;
        }
        # array
        when (/\((.+)\)/) {
            return [split /\s+/, $1];
        }
    }

    # other (such as int)
    return $value;
}

# transform from reference if necessary
sub make_value_useful {
    my $value = shift;
    given (ref $value) {
        when ('HASH') {
            return %$value;
        }
        when ('ARRAY') {
            return @$value;
        }
        when ('SCALAR') {
            return $$value;
        }
    }
    return $value;
}

sub trim {
    my $string =  shift;
       $string =~ s/\s+$//;
       $string =~ s/^\s+//;
    return $string;
}

1;

# vim: set ai et sw=4 ts=4:

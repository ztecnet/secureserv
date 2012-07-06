# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package Database;

use warnings;
use strict;

use base 'EventedObject';
use Attributes qw(file);

# Create a new Database instance.
sub new {
    my ($self, $file) = @_;
    return unless defined $file;
    bless { file => $file }, $self;
}

sub parse {
    my $self = shift;
    delete $self->{parsed};
    if (!-e $self->file) {
        $::logger->log(DATABASE_ERROR => "*** Database (".$self->file.") not found...");
        return;
    }
    if (!-r $self->file) {
        $::logger->log(DATABASE_ERROR => "*** Database (".$self->file.") not readable...");
        return;
    }

    open my $fh, '<'.$self->file or $::logger->log(DATABASE_ERROR => $!) and return;
    my @lines = <$fh>;
    foreach my $line (@lines) {
        $line = trim($line);
        my @args = split(' ', $line);
        $self->fire(@args);
    }

    close $fh;
    $self->{parsed} = 1;
    return $self;
}

sub trim {
    my $string =  shift;
       $string =~ s/\s+$//;
       $string =~ s/^\s+//;
    return $string;
}

1;

# vim: set ai et sw=4 ts=4:




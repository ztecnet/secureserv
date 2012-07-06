# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package IRC::Service;

use warnings;
use strict;
use base 'IRC::User';

sub new {
    my ($class, %opts) = @_;
    $opts{account}  ||= '0';
    $opts{ip}       ||= '0.0.0.0';

    my $service = $class->SUPER::new(
        %opts,
        server => $::me,
        id     => $main::proto->call('gen_uid'),
        mask   => $opts{host},
        ts     => time
    ) or return;

    return bless $service, $class;
}

sub send {
    my ($service, $data) = @_;
    $main::proto->fire(service_send => $service, $data);
}

sub join {
    my ($service, $chan) = @_;
    $main::proto->fire(service_join => $service, $chan);
}

sub join_logchans {
    my $service = shift;
    my %chans = $main::conf->aget('logchan');
    # XXX: We probably shouldn't join if the channel doesn't already exist. This way a network admin can join the channel and get ops before we join.
    foreach my $chan (keys %chans) {
        $main::proto->fire(service_join => $service, $chan);
    }
}

sub logchan {
    my ($service, $message) = @_;
    my %chans = $main::conf->aget('logchan');
    foreach my $chan (keys %chans) {
        $service->msg($chan, $message);;
    }
}

sub notice {
    my ($service, $target, $message) = @_;
    $main::proto->fire(service_notice => $service, $target, $message);
}

sub msg {
    my ($service, $target, $message) = @_;
    $main::proto->fire(service_message => $service, $target, $message);
}

sub has_command {
    return 1 if shift->{events}->{'cmd_'.uc(shift)};
}

1;
 
# vim: set ai et sw=4 ts=4:

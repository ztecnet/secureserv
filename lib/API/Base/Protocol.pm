# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package API::Base::Protocol;
 
use warnings;
use strict;
use Event;

sub load {
    my $mod = shift;

    $mod::synced = 0;

    # Check for required configuration values.
    foreach my $option (qw|me:name me:description me:sid link:password|) {
        if (!$::conf->get($option)) {
            $::logger->log(FATAL => "Cannot load protocol module: Missing $option in configuration.");
        }
    }

    # bind send event to the protocol object.
    $mod->on(send => sub {
        if (!$main::stream) {
            $mod->{temp_buffer} ||= [];
            push @{$mod->{temp_buffer}}, shift;
            return;
        }
        $main::stream->write(shift);
    }, 'core.send');

    # Create link hash.
    $mod->{link} = {
        name        => $::conf->get('me:name'),
        description => $::conf->get('me:description'),
        sid         => $::conf->get('me:sid'),
        password    => $::conf->get('link:password'),
    };

    # Create an Event instance.
    $mod->{event} = Event->new;

    return 1;
}

sub send {
    my ($mod, $data) = @_;
    $::logger->log(DEBUG => "<< $data");
    $mod->fire(send => "$data\n");
    return 1;
}

sub sendsid {
    my ($mod, $data) = @_;
    $mod->send(q(:).$mod->sid." $data");
    return 1;
}

sub unload {
	return 1;
}

# convenience.
sub sid      { shift->{link}->{sid}  }
sub servname { shift->{link}->{name} }
sub event    { shift->{event} }

1;

# vim: set ai et sw=4 ts=4:

# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package API::Timer;

use warnings;
use strict;
use base qw(IO::Async::Timer::Periodic EventedObject);
use Attributes qw(name delay repeat function);
use 5.010;

sub new {
    my ($class, $mod, %opts) = (shift, @_);

    # Make sure all required options are present
    foreach my $what (qw|name delay function|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        $::logger->log(TIMER_ERROR => "Timer $opts{name} does not have '$what' option.");
        return;
    }

    # create the actual timer.
    my $timer = $class->SUPER::new(
        interval => $opts{delay},
        on_tick  => sub {
            my $self = shift;
            $self->function->();
            if (!$self->repeat) {
                $self->stop;
                API::Base::Timer->delete_timer($mod, $self);
            }
        }
    ) or $::logger->log(TIMER_ERROR => "Timer $opts{name} creation failed.") and return;

    $::logger->log(TIMER_INFO => "Timer $opts{name} has been created.");
   
    $timer->{$_} = $opts{$_} foreach qw(name function repeat);
    return $timer;
}

# Start & add to loop.
sub go {
    my $timer = shift;
    $timer->start;
    $main::loop->add($timer);
    $::logger->log(TIMER_INFO => "Timer $$timer{name} started.");
    return $timer;
}

1;

# vim: set ai et sw=4 ts=4:

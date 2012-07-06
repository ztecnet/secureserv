# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::proto::charybdis;

use strict;
use warnings;
use 5.010;

our $mod = my $proto = API::Module->new(
	name         => 'proto/charybdis',
	version      => '1.0',
	description  => 'Adds Charybdis support.',
	requirements => ['Logger', 'Protocol'],
	dependencies => ['proto/ts_generic'],
	initialize   => \&init,
	void         => sub { return } # Refuse to allow unloading this module.
);

# Protocol events.
my %events = (
    sock_connect        => \&dolink,
    sock_got_line       => \&handle_line,
    PASS                => \&handle_pass,
    SERVER              => \&handle_server,
    cmd_STATS           => \&handle_stats,
    cmd_VERSION         => \&handle_version,
    cmd_PING            => \&handle_ping,
    cmd_SID             => \&handle_sid,
    cmd_EUID            => \&handle_euid,
    cmd_JOIN            => \&handle_join,
    cmd_SJOIN           => \&handle_sjoin,
    cmd_PART            => \&handle_part,
    cmd_QUIT            => \&handle_quit,
    cmd_NICK            => \&handle_nick,
    cmd_CHGHOST         => \&handle_chghost,
    cmd_PRIVMSG         => \&handle_privmsg,
    cmd_PONG            => \&handle_pong,
    cmd_AWAY            => \&handle_away,
    irc_create_user     => \&create_user,
    irc_delete_user     => \&delete_user,
    irc_set_accountname => \&set_accountname,
    service_send        => \&service_send,
    service_join        => \&service_join,
    service_message     => \&service_message,
    service_notice      => \&service_notice
);

# name => [letter, type]
my %user_modes = (
    cloaking  => ['x', 0],
    deaf      => ['D', 0],
    god       => ['S', 0],
    invisible => ['i', 0],
    ircop     => ['o', 0],
    admin     => ['a', 0],
    immune    => ['p', 0]
);

# name => [letter, type, symbol]
my %channel_modes = (
    ban        => ['b', 3],
    mute       => ['q', 3],
    key        => ['k', 2],
    userlimit  => ['l', 2],
    jointhrot  => ['j', 2],
    forward    => ['f', 2],
    secret     => ['s', 0],
    private    => ['p', 0],
    mod        => ['m', 0],
    invite     => ['i', 0],
    nocolor    => ['c', 0],
    noctcp     => ['C', 0],
    perm       => ['P', 0],
    opmod      => ['z', 0],
    noexternal => ['n', 0],
    optopic    => ['t', 0],
    op         => ['o', 4, '@'],
    voice      => ['v', 4, '+']
);

sub init {
    # Refuse to load if another protocol module is already loaded.
    return if $main::proto;

    # Sanity checking.
    if (length $::conf->get('me:sid') != 3) {
        $::logger->log(FATAL => 'Cannot load protocol module: Protocol only supports 3 character server numerics.');
    }

    # Register protocol events.
    foreach my $event (keys %events) {
        $proto->on($event => $events{$event}, "proto.$event");
    }
    undef %events;

    # Call register_modes to initialize core modes.
    register_modes();
    undef %channel_modes;
    undef %user_modes;

    # We're good.
    return 1;
}

sub register_modes {
    my (%cmodes, %umodes) = @_;
    # Register channel modes.
    foreach (keys %channel_modes) {
        IRC->create_channel_mode(
            name   => $_,
            kind   => 'channel',
            letter => $channel_modes{$_}[0],
            type   => $channel_modes{$_}[1],
            symbol => $channel_modes{$_}[2]
        );
    }

    # Register user modes
    foreach (keys %user_modes) {
        IRC->create_user_mode(
            name   => $_,
            kind   => 'user',
            letter => $user_modes{$_}[0],
            type   => $user_modes{$_}[1]
        );
    }
}


sub gen_uid {
    my $tsmod = API::is_loaded('proto/ts_generic');
    return $tsmod->call('gen_uid');
}

sub dolink {
    $proto->send('PASS '.$mod->{link}->{password}.' TS 6 '.$proto->sid);
    $proto->send('CAPAB :QS KLN UNKLN ENCAP EX CHW IE KNOCK SAVE EUID SERVICES RSFNC MLOCK TB EOPMOD BAN');
    $proto->send('SERVER '.$mod->servname.' 0 :'.$proto->{link}->{description});
    $proto->send('SVINFO 6 6 0 '.time());
    $proto->fire('burst_start');
    return 1;
}

sub handle_line {
    my $line = shift;
    $line    =~ s/\r$//;
    my @ex   = split ' ', $line;
    given(uc $ex[0]) {
        when ('PING') {
            if (!$proto::synced) {
                # Remote server is done syncing.
                $proto::synced = 1;
                $proto->fire('burst_end');
            }
            $proto->sendsid('PONG '.$proto->servname.q( ).$ex[1]);
        }
        when ('PASS') {
            if (!$proto::synced) {
                $proto->fire(PASS => $line, @ex);
            }
        }
        when ([qw(SQUIT ERROR CAPAB)]) {
            $proto->fire($_ => $line);
        }
        when ('SERVER') {
            if (!$proto::synced) {
                $proto->fire(SERVER => $line, @ex);
            }
        }
        default {
            $proto->fire('cmd_'.uc($ex[1]) => $line, @ex);
        }
    }
}

# PASS parser.
# PASS linkage TS 6 :42X
sub handle_pass {
    my (undef, @ex) = @_;
    $proto->{temp_sid} = Utils::col($ex[4]);
}

# PONG parser.
# :42X PONG irc.mattwb65.com :48X
sub handle_pong {
    my (undef, @ex) = @_;
    my $server = IRC->get_server_from_id(Utils::col($ex[0]));
    return if !$server;
    return if !$server->bursting;
    delete $server->{bursting};
    if ($server->parent == $::me) {
        $mod->log(DEBUG => 'Uplink sent EOB.');
    }
    else {
        $mod->log(DEBUG => "$$server{name} ($$server{id}) sent EOB.");
    }
}

# SERVER parser.
# SERVER irc.mattwb65.com 1 :mattwb65 IRC server
sub handle_server {
    my (undef, @ex) = @_;
    IRC->create_server(
        parent      => $::me,
        name        => $ex[1],
        id          => $proto->{temp_sid},
        description => Utils::col(join ' ', @ex[3..$#ex]),
        bursting    => 1,
    );
    # Send a PING to the server for EOB detection.
    $proto->sendsid("PING $$::me{name} $$proto{temp_sid}");
    undef $proto->{temp_sid};
}

# STATS parser.
# :42XAAAAAG STATS u :48X
sub handle_stats {
    my (undef, @ex) = @_;
    if (substr($ex[3], 1) eq $proto->sid) {
        given ($ex[2]) {
            when ('u') {
                my (undef, $days, $hours, $minutes) = Utils::get_uptime();
                $proto->sendsid("242 ".Utils::col($ex[0])." :Services Uptime: $days days, $hours hours, and $minutes minutes");
                $proto->sendsid("219 ".Utils::col($ex[0])." u :End of /STATS report");
            }
            default { $proto->fire('stats_'.$ex[2] => substr($ex[0], 1)); }
        }
    }
}

# VERSION parser.
# :42XAAAAAG VERSION :48X
sub handle_version {
    my (undef, @ex) = @_;
    if (substr($ex[2], 1) eq $proto->sid) {
        $proto->sendsid('351 '.Utils::col($ex[0])." Arinity $::VERSION ".$proto->servname);
    }
}

# PING parser.
# :00A PING services.mattwb65.com :48X
sub handle_ping {
    my (undef, @ex) = @_;
    if (substr($ex[3], 1) eq $proto->sid) {
        $proto->sendsid('PONG '.$proto->servname.q( ).$ex[0]);
    }
}

# SID parser.
# :42X SID arinity.mattwb65.com 2 48X :IRC Services
sub handle_sid {
    my (undef, @ex) = @_;
    my $server = IRC->create_server(
        parent      => IRC->get_server_from_id(Utils::col($ex[0])),
        name        => $ex[2],
        id          => $ex[4],
        description => Utils::col(join ' ', @ex[5..$#ex]),
        bursting    => 1
    );
    # Send a PING to the server for EOB detection.
    $proto->sendsid("PING $$::me{name} $ex[4]");
    $mod->log(DEBUG => "SID: Created server $ex[2] ($ex[4]) from ".Utils::col($ex[0]));
    $mod->event->fire(irc_newserver => $server);
}

# EUID parser.
# :42X EUID matthew 1 1331168707 +ailoswxz matt real.host an.ip.goes.here 42XAAAAAG masked.host matthew :Matthew
sub handle_euid {
    my (undef, @ex) = @_;
    my $user = IRC->create_user(
        nick    => $ex[2],
        ident   => $ex[6],
        mask    => $ex[7],
        gecos   => Utils::col(join ' ', @ex[12..$#ex]),
        host    => $ex[10],
        ip      => $ex[8],
        ts      => $ex[4],
        server  => IRC->get_server_from_id(Utils::col($ex[0])),
        modes   => $ex[5],
        id      => $ex[9],
        account => $ex[11]
    );
    $mod->log(DEBUG => "EUID: Created user $ex[2]!$ex[6]\@$ex[10] ($ex[9])");
    $mod->event->fire(irc_connect => $user);
}

# Away parser.
# :1SRAAAAAF AWAY :AFK
# :1SRAAAAAF AWAY
sub handle_away {
    my (undef, @ex) = @_;
    my $user = IRC->get_user_from_id(Utils::col($ex[0]));
    return if !$user;
    if ($ex[2]) {
        my $reason = Utils::col(join ' ', @ex[2..$#ex]);
        $proto->event->fire(irc_away => $user, $reason);
        $user->{away} = $reason;
    }
    else {
        delete $user->{away};
        $proto->event->fire(irc_back => $user);
    }
}


# JOIN parser.
# :42XAAAAAH JOIN 1331246876 #matthew +
sub handle_join {
    my (undef, @ex) = @_;
    my $user = IRC->get_user_from_id(Utils::col($ex[0]));
    my $chan = IRC->get_channel_from_id($ex[3]);
    push @{$chan->users}, $user;
    push @{$user->channels}, $chan;
    $mod->log(DEBUG => 'JOIN: '.$user->nick.' joined '.$chan->name);
    $proto->event->fire(irc_join => $user, $chan);
}

# SJOIN parser.
# :42X SJOIN 1331246876 #matthew +ntj 1:1 :42XAAAAAH @00AAAAAAE @+42XAAAAAG
sub handle_sjoin {
    my (undef, @ex) = @_;

    # Some things use SJOIN to join a channel and not JOIN. Ignore those, for now.
    my $exists = IRC->get_channel_from_id($ex[3]);

    my %opts = ();

    if (!$exists) {
        $opts{name} = $ex[3];
        $opts{ts} = $ex[2];
    }

    my $endparams = 4;
    foreach my $char (split(//, (split(/\+/, $ex[4]))[1])) {
        my $mode = IRC->get_channel_mode_from_letter($char);
        # If the mode isn't registered assume it has no parameters.
        next if !$mode;
        # We found the mode. Check if it has parameters.
        my $params = $mode->needs_param ~~ ['always', 'sometimes'] ? 1 : 0;
        # The mode doesn't require parameters.
        next if !$params;
        # The mode does infact require parameters. Increase endparams by 1.
        ++$endparams;
    }
    $opts{modes} = join ' ', @ex[4..$endparams];
    my @users;
    foreach my $user (split(' ', Utils::col(join ' ', @ex[$endparams+1..$#ex]))) {
        my @modes;
        # Check if the user has a prefix.
        if ($user =~ m/^(\W{1,})/) {
            foreach my $mode (split(//, $1)) {
                # The user does. Try to get the mode that goes with it.
                $mode = IRC->get_channel_mode_from_symbol($mode);
                # Couldn't find matching mode.
                next if !$mode;
                # Get mode letter.
                push @modes, $mode->letter;
            }
        }
        # Clean user up.
        $user =~ s/^\W{1,}//;
        # Get user object.
        $user = IRC->get_user_from_id($user);
        # Sanity checking.
        next if !$user;
        # Push user object to users array.
        push @users, $user;
        my $modestr = (@modes ? join q{}, @modes : 'no modes');
        $mod->log(DEBUG => "handle_sjoin: [$ex[3]] User $$user{nick} ($$user{id}) has $modestr");
    }
    if (!$exists) {
        $mod->log(DEBUG => "handle_sjoin: Got channel $ex[3] ($ex[2]). Modes: $opts{modes}.");
        my $chan = IRC->create_channel(%opts);
        foreach (@users) {
            push @{$chan->users}, $_;
            push @{$_->channels}, $chan;
        }
    }
    else {
        $mod->log(DEBUG => "handle_sjoin: Parsed as regular join.");
        foreach (@users) {
            push @{$exists->users}, $_;
            push @{$_->channels}, $exists;
            $proto->event->fire(irc_join => $_, $exists);
        }
    }
}

# PART Parser.
# :810AAACA3 PART :#doesntexist
# :810AAACA3 PART #doesntexist :hi
sub handle_part {
    my (undef, @ex) = @_;
    my $user = IRC->get_user_from_id(Utils::col($ex[0]));
    my $chan = IRC->get_channel_from_id(Utils::col($ex[2]));
    my $reason = (defined $ex[3] ? Utils::col($ex[3]) : undef);
    $chan->delete_user($user);
    $user->delete_chan($chan);
    $mod->log(DEBUG => "handle_part: $$user{nick} left $$chan{name}.");
    $proto->event->fire(irc_part => $user, $chan, $reason);
}

# PRIVMSG parser.
# :42XAAAAAG PRIVMSG #channel :hi
# :42XAAAAAG PRIVMSG 42XAAAAAU :hi
sub handle_privmsg {
    my (undef, @ex) = @_;
    my $user = IRC->get_user_from_id(Utils::col($ex[0]));
    # Redirect CTCP requests to handle_ctcp
    if (Utils::col(join ' ', @ex[3..$#ex]) =~ m/^\001(.*)\001$/) {
        # It's a CTCP. Redirect to handle_ctcp.
        handle_ctcp($user, $ex[2], $1);
        return;
    }
    my $target;
    if ($ex[2] =~ m/^#/) {
        # Message to a channel.
        $target = IRC->get_channel_from_id($ex[2]);
    }
    else {
        # Message to a user.
        $target = IRC->get_user_from_id($ex[2]);
        # Check if it's one of our clients.
        if ($target->is_service) {
            # It's a message to one of our clients.
            my $cmd = uc Utils::col($ex[3]);
            $target->fire("cmd_$cmd" => $user, @ex[4..$#ex]);
            $target->fire(cmd => $cmd, $user, @ex[4..$#ex]);
        }
        # Regardless, fire a got_privmsg.
        $target->fire(got_privmsg => $user, @ex);
    }
}

# CTCP parser.
# Args: <source user obj> <[#]target> <request>
sub handle_ctcp {
    my ($user, $target, $request) = @_;
    $request = uc $request; # This /should/ already be uppercase.
    if ($target =~ m/^#/) {
        # CTCP to channel.
        $target = IRC->get_channel_from_id($target);
    }
    else {
        # CTCP to user.
        $target = IRC->get_user_from_id($target);
        # Check if it's one of our clients.
        if ($target->is_service) {
            # It's a CTCP to one of our clients.
            $target->fire("ctcp_$request" => $user);
        }
        # Regardless, fire a got_ctcp.
        $target->fire(got_ctcp => $request, $user);
    }
}

# QUIT parser.
# :42XAAAAAH QUIT :
sub handle_quit {
    my (undef, @ex) = @_;
    my $user   = IRC->get_user_from_id(Utils::col($ex[0]));
    my $reason = Utils::col(join ' ', @ex[2..$#ex]);
    # Fire quit event here.
    IRC->delete_user($user);
    $mod->log(DEBUG => 'QUIT: '.$user->nick.' ('.$user->id.') quit '.$user->server->name." with reason: $reason");
    $proto->event->fire(irc_quit => $user, $reason);
}

# NICK parser.
# :42XAAAAAJ NICK hi2 :1331255727
sub handle_nick {
    my (undef, @ex) = @_;
    my $user = IRC->get_user_from_id(Utils::col($ex[0]));
    $mod->log(DEBUG => 'NICK: '.$user->nick.' changed his nickname to '.$ex[2]);
    $proto->event->fire(irc_nick => $user, $ex[2]);
    $user->{nick} = $ex[2];
    $user->{ts}   = Utils::col($ex[3]);
}

# CHGHOST parser.
# :00A CHGHOST 42XAAAAAG vhost.test
sub handle_chghost {
    my (undef, @ex) = @_;
    my $user = IRC->get_user_from_id($ex[2]);
    $mod->log(DEBUG => 'CHGHOST: '.$user->nick.'\'s mask was changed from '.$user->mask.' to '.$ex[3]);
    $proto->event->fire(irc_hostchange => $user, $ex[3]);
    $user->{mask} = $ex[3];
}

# irc_create_user event - Introduce a user.
sub create_user {
    my (%opts)     = @_;
    $opts{modes} ||= '+ioS';
    if ($opts{modes} !~ m/S/) { $opts{modes} .= 'S'; }

    # Check for requirements
    foreach my $what (qw|nick ident host gecos|) {
        next if exists $opts{$what};
        $opts{nick} ||= 'unknown';
        $mod->log(USER_ERROR => "Malformed introduce_user. Missing '$what' option for $opts{nick}");
        return;
    }

    $opts{id} ||= gen_uid();
    $opts{ts}  = time;
    $mod->sendsid("EUID $opts{nick} 0 $opts{ts} $opts{modes} $opts{ident} $opts{host} 0.0.0.0 $opts{id} $$proto{link}{name} * :$opts{gecos}");
    $mod->log(DEBUG => "irc_create_user: Created user $opts{nick}!$opts{ident}\@$opts{host} ($opts{id})");
}

# irc_delete_user event - Delete a user.
sub delete_user {
    my $user = shift;
    $mod->log(USER_ERROR => 'irc_delete_user: User object is not an IRC::Service.') and return if !$user->is_service;
    $user->send('QUIT :Service Deleted.');
    $mod->log(DEBUG => 'irc_delete_user: Deleted service '.$user->nick.' ('.$user->id.')');
}

# irc_set_accountname event - Set a users accountname.
sub set_accountname {
    my ($user, $account) = @_;
    $mod->sendsid("ENCAP * SU $$user{uid} $account");
    $user->{account} = $account;
    $mod->log(DEBUG => "irc_set_accountname: set $$user{nick}'s account name to $$user{account}");
}

# fired by IRC::Service with the svs->send() function.
sub service_send {
    my ($svs, $data) = @_;
    $proto->send(":$$svs{id} $data");
}

# Joins a service to a channel.
# :42X SJOIN 1331246876 #matthew +ntj 1:1 :@00AAAAAAE
sub service_join {
    my ($svs, $chan) = @_;
    $chan = lc $chan;
    my $obj = IRC->get_channel_from_id($chan);
    my $ts;
    if (!$obj) {
        $ts = time();
        IRC->create_channel(
            name  => $chan,
            ts    => $ts,
            users => $svs,
            modes => 'nt'
        );
    }
    else {
        $ts = $obj->ts;
    }
    $proto->sendsid("SJOIN $ts $chan +nt :\@$$svs{id}");
}

# Makes a service message a target.
sub service_message {
    my ($svs, $target, $message) = @_;
    $target = $target->id if (UNIVERSAL::isa($target, 'IRC::User') or UNIVERSAL::isa($target, 'IRC::Channel'));
    $proto->send(":$$svs{id} PRIVMSG $target :$message");
    return 1;
}

# Makes a service notice a target.
sub service_notice {
    my ($svs, $target, $message) = @_;
    $target = $target->id if (UNIVERSAL::isa($target, 'IRC::User') or UNIVERSAL::isa($target, 'IRC::Channel'));
    $proto->send(':$$svs{id} NOTICE $target :$message');
    return 1;
}


$mod;

# vim: set ai et sw=4 ts=4:

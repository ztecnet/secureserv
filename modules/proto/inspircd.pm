# Copyright (c) 2012 Ethrik Development Group
# see doc/LICENSE for license information.
package M::proto::inspircd;

use strict;
use warnings;
use 5.010;

our $mod = my $proto = API::Module->new(
	name         => 'proto/inspircd',
	version      => '1.0',
	description  => 'Adds InspIRCd 1.2 and above support.',
	requirements => ['Logger', 'Protocol'],
	dependencies => ['proto/ts_generic'],
	initialize   => \&init,
	void         => sub { return } # Refuse to allow unloading this module.
);

# Protocol events.
my %events = (
    sock_connect        => \&dolink,
    sock_got_line       => \&handle_line,
    SERVER              => \&handle_lserver,
    CAPAB               => \&handle_capab,
    cmd_STATS           => \&handle_stats,
    cmd_ENDBURST        => \&handle_endburst,
    cmd_SERVER          => \&handle_server,
    cmd_PING            => \&handle_ping,
    cmd_PONG            => \&handle_pong,
    cmd_UID             => \&handle_uid,
    cmd_FJOIN           => \&handle_fjoin,
    cmd_QUIT            => \&handle_quit,
    cmd_NICK            => \&handle_nick,
    cmd_FHOST           => \&handle_fhost,
    cmd_SETIDENT        => \&handle_setident,
    cmd_PRIVMSG         => \&handle_privmsg,
    cmd_PART            => \&handle_part,
    cmd_SQUIT           => \&handle_squit,
    cmd_AWAY            => \&handle_away,
    irc_create_user     => \&create_user,
    irc_delete_user     => \&delete_user,
    irc_set_accountname => \&set_accountname,
    service_send        => \&service_send,
    service_message     => \&service_message,
    service_notice      => \&service_notice,
    service_join        => \&service_join
);

# name => [letter, type]
my %user_modes = (
    invisible => ['i', 0],
    ircop     => ['o', 0]
);

# name => [letter, type, symbol]
my %channel_modes = (
    ban        => ['b', 3],
    key        => ['k', 2],
    userlimit  => ['l', 2],
    secret     => ['s', 0],
    private    => ['p', 0],
    mod        => ['m', 0],
    invite     => ['i', 0],
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

    # Call register_modes to initialize core modes.
    register_modes();
    undef %channel_modes;
    undef %user_modes;

    # We're good.
    return 1;
}

sub register_modes {
    # Register channel modes.
    foreach (keys %channel_modes) {
        $mod->log(DEBUG => "Added channel mode $_");
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
        $mod->log(DEBUG => "Added user mode $_");
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
    $proto->send('SERVER '.$mod->servname.' '.$mod->{link}->{password}.' 0 '.$mod->sid.' :'.$proto->{link}->{description});
    return 1;
}

sub handle_line {
    my $line = shift;
    $line    =~ s/\r$//;
    my @ex   = split ' ', $line;
    given(uc $ex[0]) {
        when ([qw(ERROR CAPAB)]) {
            $proto->fire($_ => $line, @ex);
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

# SERVER parser (while linking).
# SERVER test.server password 0 491 :test server
sub handle_lserver {
    my (undef, @ex) = @_;
    IRC->create_server(
        parent      => $::me,
        name        => $ex[1],
        id          => $ex[4],
        description => Utils::col(join ' ', @ex[5..$#ex]),
        bursting    => 1
    );
    $proto->sendsid("PING $$::me{id} $ex[4]");
}

# SERVER parser (during burst & after).
# :Mastodon.Hub.EU.TestNet.AlphaChat.net SERVER JoahIsFgt.CA.US.TestNet.AlphaChat.net * 1 463 :JoahIsFgt Server - Sanjose, California, US
sub handle_server {
    my (undef, @ex) = @_;
    my %opts = (
        name        => $ex[2],
        id          => $ex[5],
        description => Utils::col(join ' ', @ex[6..$#ex]),
        bursting    => 1,
    );
    my $svr = Utils::col($ex[0]);
    if (length($svr) == 3 && IRC->get_server_from_id($svr)) {
        $opts{parent} = IRC->get_server_from_id($svr);
    }
    elsif (IRC->get_server_from_name($svr)) {
        $opts{parent} = IRC->get_server_from_name($svr);
    }
    else {
        $mod->log(DEBUG => "Unable to find server that is introducing a new server.");
        return;
    }
    IRC->create_server(%opts);
    $proto->sendsid("PING $$::me{id} $ex[5]");
}

# PONG parser.
# :482 PONG 482 42X
sub handle_pong {
    my (undef, @ex) = @_;
    my $server = IRC->get_server_from_id(Utils::col($ex[0]));
    return if !$server;
    return if !$server->bursting;
    delete $server->{bursting};
    if ($server->parent == $::me) {
        $proto::synced = 1;
        $mod->log(DEBUG => 'Uplink sent EOB.');
        $mod->fire('burst_end');
    }
    else {
        $mod->log(DEBUG => "$$server{name} ($$server{id}) sent EOB.");
    }
}

# STATS parser.
# :42XAAAAAG STATS u :arinity.mattwb65.com
sub handle_stats {
    my (undef, @ex) = @_;
    if (substr($ex[3], 1) eq $proto->servname) {
        given($ex[2]) {
            when ('u') {
                my (undef, $days, $hours, $minutes) = Utils::get_uptime();
                my $user = IRC->get_user_from_id(substr($ex[0], 1));
                $proto->sendsid("PUSH $$user{id} ::$$proto{link}{name} 242 $$user{nick} :Services Uptime: $days days, $hours hours, and $minutes minutes.");
                $proto->sendsid("PUSH $$user{id} ::$$proto{link}{name} 219 $$user{nick} u :End of /STATS report");
            }
            default { $proto->fire('stats_'.$ex[2] => substr($ex[0], 1)); }
        }
    }
}

# CAPAB parser.
# CAPAB START 1202
# CAPAB MODULES :modules,separated,by,comma
# CAPAB END
# Assign a modlist array for handling CAPAB of our linked server. We'll undef this once we're done with it.
my @modlist;
sub handle_capab {
    my (undef, @ex) = @_;
    given ($ex[1]) {
        when ('MODULES')
        {
            push @modlist, $_ foreach split(',', Utils::col($ex[2]));
        }
        when ('CAPABILITIES') {
            my @capabs = split(' ', Utils::col(join ' ', @ex[2..$#ex]));
            foreach (@capabs) {
                if ($_ =~ m/PREFIX=\((.*)\)(.*)/) {
                    my @modes = split(//, $1);
                    my @symbols = split(//, $2);
                    my %mode;
                    $mode{$modes[$_]} = $symbols[$_] foreach keys @modes;
                    foreach (keys %mode) {
                        my $name;
                        given ($_) {
                            when ('q') { $mode{owner} = [$_, 4, $mode{$_}]; }
                            when ('a') { $mode{admin} = [$_, 4, $mode{$_}]; }
                            when ('h') { $mode{halfop} = [$_, 4, $mode{$_}]; }
                            when ('o') { }
                            when ('v') { }
                            default { $mod->log(DEBUG => "Got unknown mode character $_"); }
                        }
                        delete $mode{$_};
                    }
                    %channel_modes = %mode;
                    register_modes();
                    undef %channel_modes;
                }
            }
        }
        when ('END') {
            # Check for missing modules.
            if (!Utils::in_array('m_services_account.so', @modlist)) {
                $mod->log(FATAL => 'The m_services_account module is required when running Arinity with InspIRCd. Please load it and try again.');
            }
            if (!Utils::in_array('m_servprotect.so', @modlist)) {
                $mod->log(INFO => 'The m_servprotect module is not loaded. This module is not required. However, it is recommended.');
            }
            foreach (@modlist) { append_module($_); }
            do_register();
            undef @modlist;
            $proto->sendsid('BURST');
            $proto->fire('burst_start');
            $proto->sendsid("VERSION :Arinity $::VERSION $$proto{link}{sid}");
            $proto->sendsid('ENDBURST');
        }
    }
}

# PING parser.
# :1SR PING 1SR 48X
sub handle_ping {
    my (undef, @ex) = @_;
    if ($ex[3] eq $proto->sid) {
        $proto->sendsid("PONG $ex[3] $ex[2]");
    }
}

# UID parser.
# :1SR UID 1SRAAAAAF 1330632256 AlphaChat Global.Services.AlphaChat.net Global.Services.AlphaChat.net Global 0.0.0.0 1330632256 +Iio :Network Announcements
sub handle_uid {
    my (undef, @ex) = @_;
    my $user = IRC->create_user(
        nick    => $ex[4],
        ident   => $ex[7],
        mask    => $ex[6],
        gecos   => Utils::col(join ' ', @ex[11..$#ex]),
        host    => $ex[5],
        ip      => $ex[8],
        ts      => $ex[3],
        server  => IRC->get_server_from_id(Utils::col($ex[0])),
        modes   => $ex[10],
        id     => $ex[2]
    );
    $mod->log(DEBUG => "UID: Created user $ex[4]!$ex[7]\@$ex[5] ($ex[2])");
    $proto->event->fire(irc_connect => $user);
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

# ENDBURST parser.
# :553 ENDBURST
sub handle_endburst {
    my (undef, @ex) = @_;
}

# FJOIN parser.
# :553 FJOIN #lobby 1325518996 +CHKPSTfjnt 15:300 7:5 5:5 :,810AAACAZ o,1SRAAAAAO
sub handle_fjoin {
    my (undef, @ex) = @_;

    # Sometimes FJOIN is spread across more than one line. Let's find out.
    my $exists = IRC->get_channel_from_id($ex[2]);

    my %opts = ();
    if (!$exists) {
        $opts{name} = $ex[2];
        $opts{ts} = $ex[3];
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
    if (!$exists) { $opts{modes} = join ' ', @ex[4..$endparams]; }
    my @users = ();
    foreach my $user (split(' ', Utils::col(join ' ', @ex[$endparams+1..$#ex]))) {
        my @modes;
        my ($letters, $uid) = split(",", $user);
        # Check if the user has a prefix.
        foreach my $mode (split(//, $letters)) {
            # The user does. Try to get the mode that goes with it.
            $mode = IRC->get_channel_mode_from_letter($mode);
            # Couldn't find matching mode.
            next if !$mode;
            # Get mode letter.
            push @modes, $mode->letter;
        }
        # Get user object.
        $user = IRC->get_user_from_id($uid);
        # Sanity checking.
        next if !$user;
        # Push user object to users array.
        push @users, $user;
        my $modestr = (@modes ? join q{}, @modes : 'no modes');
        $mod->log(DEBUG => "handle_fjoin: [$ex[2]] User $$user{nick} ($$user{id}) has $modestr");
    }
    my $server = IRC->get_server_from_id(Utils::col($ex[0]));

    if (!$exists and $server->bursting) {
        $mod->log(DEBUG => "handle_fjoin: Got channel $ex[2] ($ex[3]). Modes: $opts{modes}.");
        my $chan = IRC->create_channel(%opts);
        foreach (@users) {
            push @{$chan->users}, $_;
            push @{$_->channels}, $chan;
        }
        $proto->event->fire(irc_chancreate => $chan);
    }
    elsif ($exists and $server->bursting) {
        foreach (@users) {
            push @{$exists->users}, $_;
            push @{$_->channels}, $exists;
        }
        $mod->log(DEBUG => "handle_fjoin: Got additional users for $ex[2].");
    }
    elsif (!$exists and !$server->bursting) {
        my $chan = IRC->create_channel(%opts);
        my $user = $users[0];
        $mod->log(DEBUG => "handle_fjoin: $$user{nick} created $$chan{name}.");
        $proto->event->fire(irc_chancreate => $chan, $user);
    }
    else {
        my $user = $users[0];
        $mod->log(DEBUG => "handle_fjoin: $$user{nick} joined $$exists{name}");
        $proto->event->fire(irc_join => $user, $exists);
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
    $proto->event->fire(irc_part => $user, $chan, $reason);
    $chan->delete_user($user);
    $user->delete_chan($chan);
    $mod->log(DEBUG => "handle_part: $$user{nick} left $$chan{name}.");
}

# PRIVMSG Parser.
# :42XAAAAAG PRIVMSG #channel :hi
# :42XAAAAAG PRIVMSG 42XAAAAAU :hi
sub handle_privmsg {
    my (undef, @ex) = @_;
    my $user = IRC->get_user_from_id(Utils::col($ex[0]));
    # InspIRCd has some modules that will send messages from a nonexistant user (eg. a server). Handle that here.
    $mod->log(DEBUG => 'handle_privmsg: Got unknown user, bailing.') and return if !$user;
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
# QUIT parser.
# :42XAAAAAH QUIT :
sub handle_quit {
    my (undef, @ex) = @_;
    my $user   = IRC->get_user_from_id(Utils::col($ex[0]));
    my $reason = Utils::col(join ' ', @ex[2..$#ex]);
    $mod->log(DEBUG => 'QUIT: '.$user->nick.' ('.$user->id.') quit '.$user->server->name." with reason: $reason");
    $proto->event->fire(irc_quit => $user, $reason);
    IRC->delete_user($user);
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

# FHOST parser.
sub handle_fhost {
    my (undef, @ex) = @_;
    my $user = IRC->get_user_from_id(Utils::col($ex[0]));
    my $mask = Utils::col($ex[2]);
    $mod->log(DEBUG => 'FHOST: '.$user->nick.'\'s mask was changed from '.$user->mask.' to '.$mask);
    $proto->event->fire(irc_hostchange => $user, $mask);
    $user->{mask} = $ex[2];
}

# SETIDENT parser.
sub handle_setident {
    my (undef, @ex) = @_;
    my $user = IRC->get_user_from_id(Utils::col($ex[0]));
    $mod->log(DEBUG => 'SETIDENT: '.$user->nick.'\'s ident was changed from '.$user->ident.' to '.Utils::col($ex[3]));
    $user->{ident} = Utils::col($ex[3]);
}

# SQUIT parser.
sub handle_squit {
    my (undef, @ex) = @_;
    my $svr = $ex[2];
    my $server;
    if (length($svr) == 3 && IRC->get_server_from_id($svr)) {
        $server = IRC->get_server_from_id($svr);
    }
    elsif (IRC->get_server_from_name($svr)) {
        $server = IRC->get_server_from_name($svr);
    }
    foreach my $child (IRC->get_servers_from_parent($server)) {
        $mod->log(DEBUG => "handle_squit: Deleted child $$child{name} from $$server{name} splitting.");
        IRC->delete_server($child);
    }
    $mod->log(DEBUG => "handle_squit: Deleted $$server{name}");
    IRC->delete_server($server);
}

# Module appender. This takes a module and appends what it provides to a hash.
sub append_module {
    my $name = shift;
    given ($name) {
        when ('m_invisible.so') {
            $mod->log(FATAL => 'The Arinity team does not support InspIRCd instances with m_invisible. Please unload it or use another services provider.');
        }
        when ('m_serv_protect.so') {
            $user_modes{god} = ['k', 0];
        }
        when ('m_allowinvite.so') {
            $channel_modes{anyinvite} = ['A', 0];
        }
        when ('m_blockcaps.so') {
            $channel_modes{nocaps} = ['B', 0];
        }
        when ('m_blockcolor.so') {
            $channel_modes{nocolor} = ['c', 0];
        }
        when ('m_noctcp.so') {
            $channel_modes{noctcp} = ['C', 0];
        }
        when ('m_delayjoin.so') {
            $channel_modes{joindelay} = ['D', 0];
        }
        when ('m_banexception.so') {
            $channel_modes{banexcept} = ['e', 3];
        }
        when ('m_messageflood.so') {
            $channel_modes{msgflood} = ['f', 2];
        }
        when ('m_nickflood.so') {
            $channel_modes{nickflood} = ['F', 2];
        }
        when ('m_chanfilter.so') {
            $channel_modes{chancensor} = ['g', 3];
        }
        when ('m_censor.so') {
            $channel_modes{censor} = ['G', 0];
        }
        when ('m_inviteexception.so') {
            $channel_modes{inviteexcept} = ['I', 3];
        }
        when ('m_joinflood.so') {
            $channel_modes{jointhrot} = ['j', 2];
        }
        when ('m_kicknorejoin.so') {
            $channel_modes{kickrejoin} = ['J', 2];
        }
        when ('m_knock.so') {
            $channel_modes{nokick} = ['K', 0];
        }
        when ('m_redirect.so') {
            $channel_modes{redirect} = ['L', 2];
        }
        when ('m_services_account.so') {
            $channel_modes{reginvite} = ['R', 0]; # Unidentified users cannot join.
            $channel_modes{regmoderated} = ['M', 0]; # Unidentified users cannot message.
            $channel_modes{registered} = ['r', 0]; # Marks a channel as registered.
            $user_modes{registered} = ['r', 0]; # Marks a user as registered.
            $user_modes{regdeaf} = ['R', 0]; # Unidentified users cannot message a user.
        }
        when ('m_nonicks.so') {
            $channel_modes{nonick} = ['N', 0];
        }
        when ('m_operchans.so') {
            $channel_modes{operchan} = ['O', 0];
        }
        when ('m_permchannels.so') {
            $channel_modes{perm} = ['P', 0];
        }
        when ('m_nokicks.so') {
            $channel_modes{nokick} = ['Q', 0];
        }
        when ('m_stripcolor.so') {
            $channel_modes{stripcolor} = ['S', 0];
        }
        when ('m_nonotice.so') {
            $channel_modes{nonotice} = ['T', 0];
        }
        when ('m_auditorium.so') {
            $channel_modes{auditorium} = ['u', 0];
        }
        when ('m_sslmodes.so') {
            $channel_modes{sslonly} = ['z', 0];
        }
        when ('m_deaf.so') {
            $user_modes{deaf} = ['u', 0];
        }
        when ('m_opmoderated.so') {
            $channel_modes{opmod} = ['U', 0];
        }
        when ('m_namedmodes.so') {
            $channel_modes{namedmode} = ['N', 1];
        }
        when ('m_chanhistory.so') {
            $channel_modes{history} = ['H', 2];
        }
        when ('m_exemptchanops.so') {
            $channel_modes{opexempt} = ['X', 1];
        }
        when ('m_autoop.so') {
            $channel_modes{autoop} = ['w', 3];
        }
        default {
            $mod->log(DEBUG => "Got unknown module: $name");
       }
    }
}

# Register modes after making hash.
sub do_register { 
    register_modes(); 
    undef %channel_modes; 
    undef %user_modes; 
}

# irc_create_user event - Introduce a user.
sub create_user {
    my (%opts)     = @_;
    $opts{modes} ||= '+io';

    # Check for requirements
    foreach my $what (qw|nick ident host gecos|) {
        next if exists $opts{$what};
        $opts{nick} ||= 'unknown';
        $mod->log(USER_ERROR => "Malformed introduce_user. Missing '$what' option for $opts{nick}");
        return;
    }

    $opts{id} ||= gen_uid();
    $opts{ts}  = time;
    $mod->sendsid("UID $opts{id} $opts{ts} $opts{nick} $opts{host} $opts{host} $opts{ident} 0.0.0.0 $opts{ts} $opts{modes} * :$opts{gecos}");
    $mod->send(":$opts{id} OPERTYPE Service");
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
    $mod->sendsid("METADATA $$user{uid} accountname :$account");
    $user->{account} = $account;
    $mod->log(DEBUG => "irc_set_accountname: set $$user{nick}'s account name to $$user{account}");
}

# fired by IRC::Service with the svs->send() function.
sub service_send {
    my ($svs, $data) = @_;
    $proto->send(":$$svs{id} $data");
}

# Joins a service to a channel.
# :1SR FJOIN #Services 1333053713 + :o,1SRAAAAAT
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
            modes => 0
        );
    }
    else {
        $ts = $obj->ts;
    }
    $proto->sendsid("FJOIN $chan $ts + :o,$$svs{id}");
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
    $proto->send(":$$svs{id} NOTICE $target :$message");
    return 1;
}


$mod;

# vim: set ai et sw=4 ts=4:

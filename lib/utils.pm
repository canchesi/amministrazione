package utils;

use strict;
use warnings;
use JSON;
use IO::Socket;

# Prepares a message to be sent through the socket
sub prepare_send_message { # Parameters: message, last
    my $message = shift;
    my $last = shift || 0;
    my $limit = 1024;
    my $length = length($message);
    my $is_end = 0;
    my $almost_end = 0;
    my @split_message = ();
    
    while ($length+7 > $limit && !$is_end) {
        if ($length <= $limit) {
            $is_end = 1;
        }
        my $partial = substr $message, 0, $limit;
        if ($is_end) {
            $limit = $length;
        }
        $message = substr($message, $limit);
        $length = length($message);
        push @split_message, $partial;
    }
    $message .= "END"; 
    if ($last) {
        $message = $message. "LAST";
    }
    push @split_message, $message;
    return @split_message;
}

# Receives a message through the socket
sub receive_message { # Parameters: socket
    my $socket = shift || return undef;
    my $limit = 1024;
    my $response = "";
    my $partial = "";
    my $length = length($response);

    while (1) {    
        $socket->recv($partial, $limit);
        $response .= $partial;
        if ($partial =~ /.*END$/ || $partial =~ /.*ENDLAST$/) {
            last;
        }
    }
    if ($response =~ /.*ENDLAST$/) {
        $response = substr($response, 0, -7);
        return $response . "LAST";
    }
    return substr($response, 0, -3);

}

# Sends a message through the socket
sub send_message { # Parameters: socket, message, last
    my $socket = shift || return undef;
    my $message = shift || return undef;
    my $last = shift || 0;
    my $limit = 1024;
    if (!length($message)) {
        $socket->send("END", IO::Socket::MSG_NOSIGNAL);
    } else  {
        my @msg = prepare_send_message($message, $last);
        foreach my $message (@msg) {
            $socket->send($message, IO::Socket::MSG_NOSIGNAL);
        }
    }
    return 0;
}

# Waits. Used for debugging
sub wait {
    my $msg = shift || "Waiting...";
    while (1){
        print $msg . "\n";
        sleep 1;
    }
} 

# Reads the users.json file and returns a hash with the users and their directories
sub read_user_json {
    my $user = shift || "";
    chop $user;
    open(my $json_file, '<', '/etc/back/users.json') or return undef;
    my $json_text = join('', <$json_file>);
    close($json_file);
    my $json_data = decode_json($json_text);

    if ($user ne "") {
        return $json_data->{$user}->{"directories"};
    }

    return $json_data;
}

# Checks if a user exists in the users.json file
sub user_exists {
    my $user = shift || "";
    my $json_data = read_user_json();
    my $exists = 0;
    $user = `id -u $user`;
    $exists = `grep 'x:$user:' /etc/passwd`;

    if ($exists eq "") {
        return 2;
    }

    chomp $user;
    foreach my $key (keys $json_data->%*) {
        chomp $key;
        if ($key eq $user) {
            return 0;
        }
    }
    return 1;
}

# Reads the config file and returns a hash with the config
sub read_config {
    my $config_file = "/etc/back/back.conf";
    my $config = {};
    open(my $config_fh, '<', $config_file) or return undef;
    while (my $line = <$config_fh>) {
        chomp $line;
        if ($line =~ /^#/) {
            next;
        }
        my ($key, $value) = split(/=/, $line);
        $config->{$key} = $value;
    }
    close($config_fh);
    return $config;
}

1;
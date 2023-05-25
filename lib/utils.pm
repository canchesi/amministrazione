package utils;

use strict;
use warnings;
use JSON;

sub prepare_send_message { # Parametri: messaggio,  ultimo
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

sub receive_message { # Parametri: socket, limite
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

sub send_message { # Parametri: socket, messaggio, ultimo
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

sub wait {
    my $msg = shift || "Waiting...";
    while (1){
        print $msg . "\n";
        sleep 1;
    }
} 

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

sub user_exists {
    my $user = shift || "";
    my $json_data = read_user_json();
    my $exists = 0;
    
    $exists = `grep '^$user:' /etc/passwd`;

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

1;
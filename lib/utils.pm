package utils;

use strict;
use warnings;

sub prepare_send_message { # Parametri: messaggio, limite, ultimo
    my $message = shift;
    my $limit = shift || 1024;
    my $last = shift || 0;
    my $length = length($message);
    my $is_end = 0;
    my $almost_end = 0;
    my @split_message = ();
    
    if ($last) {
        $message = "LAST" . $message;
    }
    if ($limit <= 3){
        $limit = 1024;
    }
    while ($length+3 > $limit && !$is_end) {
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
    push @split_message, $message;
    return @split_message;
}

sub receive_message { # Parametri: socket, limite
    my $socket = shift || return undef;
    my $limit = shift || 1024;
    my $response = "";
    my $partial = "";
    my $length = length($response);
    if ($limit <= 3) {
        $limit = 1024;
    }

    while (1) {    
        $socket->recv($partial, $limit);
        $response .= $partial;
        if ($partial =~ /.*END$/) {
            last;
        }
    }
    return substr($response, 0, -3);

}

sub send_message { # Parametri: socket, messaggio, limite, ultimo
    my $socket = shift || return undef;
    my $message = shift || return undef;
    my $limit = shift || 1024;
    my $last = shift || 0;
    if (!length($message)) {
        $socket->send("END");
    } else  {
        my @msg = prepare_send_message($message, $limit, $last);
        foreach my $message (@msg) {
            $socket->send($message);
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

sub send_receive { # Parametri: socket, messaggio, limite
    my $socket = shift || return undef;
    my $message = shift || return undef;
    my $limit = shift || 1024;
    my $response = undef;

    send_message($socket, "RISP" . $message, $limit, 0);
    $response = receive_message($socket, $limit);
    return $response;
}

1;
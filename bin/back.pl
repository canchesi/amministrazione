#! /usr/bin/perl

use warnings;
use strict;
use IO::Socket::UNIX;
use Switch;
use lib "./lib";
use utils;

# Creates a socket and connects to the daemon
my $socket = IO::Socket::UNIX->new(
    Type => SOCK_STREAM(),
    Peer => "/run/back.sock"
);

# If there is an error connecting to the daemon, exit
if (!defined $socket) {
    print "Error connecting to the daemon.\n";
    exit 1;
}

my $commands = "";  # Commands to be sent to the daemon
my $response = "";  # Response from the daemon

# Concatenate all the arguments into a single string
foreach my $command (@ARGV) {
    $commands .= $command . " ";
}
$commands = substr $commands, 0, -1;

# If there are no arguments, send --help to the daemon
if ($commands eq "") {
    $commands = "--help";
}

# Send the commands to the daemon
utils::send_message($socket, $commands);

while (1) {
    # Receive the response from the daemon
    my $response = utils::receive_message($socket);
    
    # If the response ends with LAST, remove it and print the last response
    # else print the response and continue
    if ($response =~ /.*LAST$/) {
        $response = substr $response, 0, -4;
        print $response . "\n";
        last;
    } else {
        print $response . "\n";
    }
}

$socket->close();
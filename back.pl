#! /usr/bin/perl

use warnings;
use strict;
use IO::Socket::UNIX;
use Switch;
require "./lib/utils.pm";

my $socket = IO::Socket::UNIX->new(
    Type => SOCK_STREAM(),
    Peer => "/run/back.sock"
);


if (!defined $socket) {
    print "Error connecting to the daemon.\n";
    exit 1;
}

my $commands = "";
my $response = "";

foreach my $command (@ARGV) {
    $commands .= $command . " ";
}
$commands = substr $commands, 0, -1;

utils::send_message($socket, $commands);

while (1) {
    my $response = utils::receive_message($socket);
    if ($response =~ /^LAST.*/) {
        print substr $response . "\n", 4;
        last;
    } else {
        print $response . "\n";
    }
}

$socket->close();
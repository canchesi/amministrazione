#! /usr/bin/perl

use warnings;
use strict;
use IO::Socket::UNIX;
use Switch;
use lib "./lib";
use utils;

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
if ($commands eq "") {
    $commands = "--help";
}
utils::send_message($socket, $commands);

while (1) {
    my $response = utils::receive_message($socket);
    if ($response =~ /.*LAST$/) {
        $response = substr $response, 0, -4;
        print $response . "\n";
        last;
    } else {
        print $response . "\n";
    }
}

$socket->close();
#! /usr/bin/perl

use warnings;
use strict;
use IO::Socket::UNIX;
use Switch;

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

print $socket $commands . "\n";

while (my $partial = <$socket>) {
    chomp $partial;
    $response .= $partial . "\n";
}

print $response;
$socket->close();
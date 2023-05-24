package interface;

require './commands/users.pm';
require './commands/keygen.pm';
require './lib/conn.pm';
require './lib/utils.pm';
use strict;

use warnings;
use Switch;
use JSON;
use Switch;

my $socket = conn::create_socket();
$socket->autoflush;

sub interface {
    while (1) {
        my $connection = conn::accept_connection($socket);
        handle_connection($connection);
    }

}

sub handle_connection {
    my $connection = shift;
    my $request = utils::receive_message($connection);
    chomp $request;
    my $response = command_handler($connection, $request);    
    if ($response eq "1") {
        # Ignore 
    } else {
        utils::send_message($connection, $response, 1024, 1);
    }
}

sub command_handler {
    my $connection = shift @_;
    my @commands = split / /, $_[0];
    my $command = shift @commands;
    my $response = undef;
    switch ($command) {
        case "--help" {
            # TODO DA SISTEMARE
        }
        case /^(-v|--version)$/ {
            $response = "Back-a-la 0.1.0";
        }
        case "user" {
            $response = commands::user::parse(@commands);
        }
        case "keygen" {
            $response = commands::keygen::keygen($connection, @commands);
        }
        case "" { $response = "No command given"; }
        else { $response = "Command not found"; }
    }
    return $response;
}
1;
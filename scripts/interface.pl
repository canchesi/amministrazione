require './commands/users.pm';
require './lib/conn.pm';
use strict;

use warnings;
use Switch;
use JSON;
use Switch;

my $socket = conn::create_socket();
sub interface {
    while (1) {
        my $connection = conn::accept_connection($socket);
        handle_connection($connection);
    }

}

sub handle_connection {
    my $connection = shift;
    my $request = <$connection>;
    chomp $request;
    my $response = command_handler($request);    
    print $connection $response;
    conn::close_socket($connection);

}

sub command_handler {
    my @commands = split / /, $_[0];
    my $command = shift @commands;
    my $response = undef;
    switch ($command) {
        case "--help" {} # TODO DA SISTEMARE
        case /^(-v|--version)$/ { $response = "Back-a-la 0.1.0"; }
        case "users" { $response = commands::users::parse(@commands); }
        case "" { $response = "No command given"; }
        else { $response = "Command not found"; }
    }
    return $response;
}

interface();
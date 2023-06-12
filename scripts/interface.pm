package interface;

use users;
use keygen;
use backup;
use restore;
use set;
use dirs;
use conn;
use utils;

use strict;
use warnings;
use Switch;
use JSON;
use threads;

my $socket = conn::create_socket();
$socket->autoflush;

$SIG{TERM} = sub {};

# Main loop
sub interface {
    while (1) {
        my $connection = conn::accept_connection($socket);
        my $thread = threads->create(\&handle_connection, $connection);
    }

}

# Handles a connection
sub handle_connection {
    my $connection = shift;
    my $request = utils::receive_message($connection); chomp $request;
    my $response = command_handler($connection, $request);
    utils::send_message($connection, $response, 1);
}

# Handles a command received through the socket
sub command_handler {
    my $connection = shift @_;
    my $help = "Usage: backctl [OPTIONS]\n\n" .
               "Options: \n" .
               "  keygen\t\t\t\tGenerate new keys\n" .
               "  user\t\t\t\tManage users\n" .
               "  backup\t\t\t\tPerform a backup fot a selected user\n" .
               "  restore\t\t\t\tPerform a restore of a backup for a selected user\n" .
               "  set\t\t\t\tSet the period for automatic backups for a selected user\n" .
               "  directory\t\t\t\tManage directories to be backed up for a selected user";
    if (scalar @_ == 0) {
        return $help;
    }
    my @commands = split / /, $_[0];
    my $command = shift @commands;
    my $response = undef;

    switch ($command) {
        case "user" {
            $response = commands::user::parse(@commands);
        }
        case "keygen" {
            $response = commands::keygen::keygen($connection, @commands);
        }
        case "backup" {
            $response = commands::backup::parse($connection, @commands);
        }
        case "restore" {
            $response = commands::restore::restore($connection, @commands);
        }
        case "set" {
            $response = commands::set::set(@commands);
        }
        case "directory" {
            $response = commands::dirs::directory(@commands);
        }
        else {
            $response = $help;
        }
    }
    return $response;
}
1;
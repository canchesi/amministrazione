package interface;

require './commands/users.pm';
require './commands/keygen.pm';
require './commands/backup.pm';
require './commands/restore.pm';
require './commands/set.pm';
require './lib/conn.pm';
require './lib/utils.pm';

use strict;
use warnings;
use Switch;
use JSON;
use threads;

my $socket = conn::create_socket();
$socket->autoflush;

$SIG{TERM} = sub {};

sub interface {
    while (1) {
        my $connection = conn::accept_connection($socket);
        my $thread = threads->create(\&handle_connection, $connection);
    }

}

sub handle_connection {
    my $connection = shift;
    my $request = utils::receive_message($connection); chomp $request;
    my $response = command_handler($connection, $request);
    utils::send_message($connection, $response, 1);
}

sub command_handler {
    my $connection = shift @_;
    my $help = "Usage: backctl [OPTIONS]\n" .
               "Options: \n" .
               "  user\t\t\t\tManage users\n" .
               "  keygen\t\t\t\tGenerate new keys\n" .
               "  backup\t\t\t\tPerform a backup fot a selected user\n" .
               "  -h, --help\t\t\tShow this help message\n" .
               "  -v, --version\t\t\tShow the version of the program\n";
    if (scalar @_ == 0) {
        return $help;
    }
    my @commands = split / /, $_[0];
    my $command = shift @commands;
    my $response = undef;
    my $stop = 0;

    switch ($command) {
        case /^(-v|--version)$/ {
            $response = "Back-a-la 0.1.0";
        }
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
        else {
            $response = $help;
        }
    }
    return $response;
}
1;
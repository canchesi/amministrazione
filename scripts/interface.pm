package interface;

require './commands/users.pm';
require './commands/keygen.pm';
require './commands/backup.pm';
require './lib/conn.pm';
require './lib/utils.pm';

use strict;
use warnings;
use Switch;
use JSON;
use Thread;

my $socket = conn::create_socket();
my @conns = ();
my @threads = ();
$socket->autoflush;

$SIG{TERM} = sub {};

sub interface {
    while (1) {
        my $connection = conn::accept_connection($socket);
        my $thread = Thread->new(\&handle_connection, $connection);
        push @conns, $connection;
        push @threads, $thread;
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
        utils::send_message($connection, $response, 1);
    }
}

sub command_handler {
    my $connection = shift @_;
    my @commands = split / /, $_[0];
    my $command = shift @commands;
    my $response = undef;
    my $stop = 0;
    my $help = "Usage: backctl [OPTIONS]\n" .
               "Options: \n" .
               "  -h, --help\t\t\tShow this help message\n" .
               "  -v, --version\t\t\tShow the version of the program\n" .
               "  user\t\t\t\tManage users\n" .
               "  keygen\t\t\t\tGenerate new keys\n" .
               "  backup\t\t\t\tPerform a backup fot a selected user\n";

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
        case "backup" {
            $response = commands::backup::backup($connection, @commands);
        }
    }
    return $response;
}
1;
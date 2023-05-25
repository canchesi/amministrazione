package commands::backup;

use warnings;
use strict;
use Text::Table;
use Switch;
use JSON;
require "./lib/utils.pm";
require "./scripts/zipper.pm";

no warnings 'experimental';



sub backup {
    my $connection = shift @_;
    my $user = "";
    my @paths = ();
    my $stop = 0;

    my $help = "Usage: backup [OPTIONS]\n" .
               "Options: \n" .
               "  -u, --user\t\t\tUser for which to perform the backup\n";

    foreach my $command (@_) {
        if ($command =~ /^(-u|--user)$/) {
            shift @_; $user = shift @_; $user = `id -u $user`;
            my $exists = utils::user_exists($user);
            if ($user eq "" || $user =~ /^-.*/) {
                return $help;
            } elsif ($exists == 2) {
                return "User does not exist in the system";
            } elsif ($exists == 1) {
                return "User does not exist in Back-a-la system";
            } elsif (`id -u $user` < 1000) {
                return "Impossible to make a backup of a system user";
            }
        } else {
            return $help;
        }
    }
    utils::send_message($connection, "Backup started. It may take a while, please wait...");
    $SIG{INT} = sub { utils::send_message($connection, "Backup interrupted. Back-a-la interrupted the connection", 1); };
    if (zipper::zip($user) == 0) {
        $SIG{INT} = sub {};
        return "Backup performed successfully";
    } else {
        return "Backup failed";
    }

}

1;
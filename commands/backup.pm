package commands::backup;

use warnings;
use strict;
use Text::ASCIITable;
use Switch;
use JSON;
use File::Path;
use Thread;
use Time::HiRes qw(time);
use utils;
use zipper;

no warnings 'experimental';

# Read the configuration file
my $config = utils::read_config();

# Parse the command
sub parse {
    my $connection = shift @_;      # Connection to the daemon
    my $command = shift @_ || "";   # Command to be parsed
    my $help =  "Usage: backctl backup COMMAND [OPTIONS]\n\n" .
                "Perform a backup for a selected user or lists all the backups for a selected user.\n" .
                "Command: \n" .
                "  ls\t\t\tList all the backups for a selected user\n" .
                "  start\t\t\tStart a backup for a selected user" .
		"  del\t\t\tDelete a backup for a selected user";

    # Check the command
    switch ($command) {
        case "ls" {
            return ls(@_);
        }
        case "start" {
            return start($connection, @_);
        }
        case "del" {
            return del(@_);
        }
        else {
            return $help;
        }
    }

}

# List all the backups for a selected user
sub ls {
    my $help = "Usage: backctl backup ls [OPTIONS]\n\n" .
                "List all the backups recorded in the system.\n" .
                "Options: \n" .
                "  -u, --user USER\t\tUser for which to list the backups";
    
    # Read the user configuration file
    my $json_data = utils::read_user_json();
    
    # Creates the table
    my $table = Text::ASCIITable->new({});
    $table->setCols("NAME", "DIRECTORIES", "DATES");
    # User informations
    my %users = (names => [], ids => []);

    # Parse the commands
    foreach my $command (@_) {
        # Take the user
        if ($command =~ /^(-u|--user)$/) {
            shift @_; my $user = shift @_ || ""; chomp $user;
            if ($user eq "" || $user =~ /^-.*/) {
                return $help;
            }
            # Creates the users list
            @{$users{names}} = split ',', $user;
            for (my $i = 0; $i < scalar @{$users{names}}; $i++) {
                # For each user, check if it exists and if it is a system user
                my $exists = utils::user_exists($users{names}[$i]);
                if ($users{names} =~ /^-.*/) {
                    return $help;
                } elsif ($exists == 2) {
                    return "User $users{names}[$i] does not exist in the system";
                } elsif (`id -u $users{names}[$i]` < 1000) {
                    return "Impossible to make a backup of a system user ($users{names}[$i])";
                }elsif ($exists == 1) {
                    return "User $users{names}[$i] does not exist in Back-a-la system";
                }
                $users{ids}[$i] = `id -u $users{names}[$i]`;
                $users{names}[$i] = `id -un $users{names}[$i]`;
                if (`id -u $users{ids}[$i]` < 1000) {
                    return "Impossible to make a backup of a system user ($users{names}[$i])";
                }
            }
        } else {
            return $help;
        }
    }

    # If no user is specified, list all the users
    if (scalar @{$users{names}} == 0) {
        @{$users{names}} = keys $json_data->%*;
        for (my $i = 0; $i < scalar @{$users{names}}; $i++) {
            $users{names}[$i] = `id -un $users{names}[$i]`;
            $users{ids}[$i] = `id -u $users{names}[$i]`;
        }
    }
    #@{$users{names}} = sort @{$users{names}};
    #@{$users{ids}} = sort @{$users{ids}};
    chomp @{$users{names}};
    chomp @{$users{ids}};

    # For each user, prepare the table
    foreach (my $i = 0; $i < scalar @{$users{names}}; $i++) {
        my $user_dir = $config->{"BACKUP_DIR"} . ($config->{"BACKUP_DIR"} =~ /\/$/ ? "" : "/") . $users{ids}[$i]; chomp $user_dir;
        my @backups = `ls -t -l $user_dir | grep -v total | awk '{print \$9}'`; chomp @backups;
        my $dates = "";
        my $dirs = "";
        if (! -d $user_dir) {
            next;
        }
        
        foreach my $dir ($json_data->{$users{ids}[$i]}->{"directories"}->@*) {
            $dirs .= $dir . "\n";
        } chomp $dirs;
        foreach (my $i = 0; $i < scalar @backups; $i++) {
            $dates .= $i+1 . ($i > 8 ? ") " : ")  ") . get_date($backups[$i]) . "\n";
        }
        $table->addRow($users{names}[$i], $dirs, $dates);
        $table->addRowLine();
    }
    return $table;
}

sub start {
    my $connection = shift @_;
    my $user = "";
    my @users = ();
    my @paths = ();
    my $stop = 0;
    my @threads = ();
    my $ok = 0;
    my $help =  "Usage: backctl backup start [OPTIONS]\n\n" .
                "Perform a backup for a selected list of users.\n" .
                "Options: \n" .
                "  -u, --user USER\t\tUser for which to perform the backup";

    # Parse the commands
    foreach my $command (@_) {
        # Take the user
        if ($command =~ /^(-u|--user)$/) {
            shift @_; $user = shift @_;
            @users = split ',', $user;
            # For each user, check if it exists and if it is a system user
            for (my $i = 0; $i < scalar @users; $i++) {
                $users[$i] = `id -u $users[$i]`;
                my $exists = utils::user_exists($users[$i]);
                if ($user eq "" || $user =~ /^-.*/) {
                    return $help;
                } elsif ($exists == 2) {
                    return "User $user does not exist in the system";
                } elsif (`id -u $users[$i]` < 1000) {
                    return "Impossible to make a backup of a system user ($user)";
                } elsif ($exists == 1) {
                    return "User $user does not exist in Back-a-la system";
                }
            }
            $ok = 1;
        } else {
            return $help;
        }
    }
    # The user is mandatory
    if ($ok == 0) {
        return $help;
    }
    utils::send_message($connection, "Backup started. It may take a while, please wait...");
    my $time = time();
    $SIG{INT} = sub { utils::send_message($connection, "Backup interrupted. Back-a-la interrupted the connection", 1); };
    # For each user, start a thread to perform the backup
    foreach my $user (@users) {
        push @threads, threads->create(\&zipper::zip, $user);
    }

    # Wait for all the threads to finish
    while ($stop < scalar @threads) {
        foreach my $thread (@threads) {
            if ($thread->is_joinable()) {
                my @res = $thread->join();
                if ($res[0] == 1) {
                    return "Backup failed for user $res[1] (zip failed, maybe not enough space)";
                } elsif ($res[0] == 2) {
                    return "Backup failed for user $res[1] (encryption failed)";
                } elsif ($res[0] == 3) {
                    return "Backup failed for user $res[1] (not enough memory in storage)";
                    `notify-send -u critical "Back-a-la" "Backup failed for user $res[1] (not enough memory in storage)"`;
                }
                $stop++;
            } 
        }
    }

    return "All backups performed successfully. (" . (time() - $time). ")";
    $SIG{INT} = sub {};
}

sub del {
    my $user = "";
    my $number = "";
    my @ok = (0, 0);
    my $help =  "Usage: backctl backup del [OPTIONS]\n\n" .
                "Delete a backup for a selected user.\n" .
                "Options: \n" .
                "  -u, --user USER\t\tUser for which to delete the backup\n" .
                "  -n, --number NUMBER\t\tNumber of the backup to delete";

    # Parse the commands
    foreach my $command (@_) {
        # Take the user
        if ($command =~ /^(-u|--user)$/) {
            shift @_; $user = shift @_; 
            $user = `id -u $user`; chomp $user;
            my $exists = utils::user_exists($user);
            if ($user eq "" || $user =~ /^-.*/) {
                return $help;
            } elsif ($exists == 2) {
                return "User does not exist in the system";
            } elsif ($exists == 1) {
                return "User does not exist in Back-a-la system";
            } elsif (`id -u $user` < 1000) {
                return "Impossible to delete a backup of a system user ($user)";
            }
            $ok[0] = 1;
        } elsif ($_[0] =~ /^(-n|--number)$/) {
            # Take the number
            shift @_; $number = shift @_; chomp $number;
            if ($number eq "" || $number =~ /^-.*/) {
                return $help;
            } elsif ($number !~ /^([0-9]|10)$/ || $number == 0) {
                return "Invalid number. Please select a number between 1 and 10.\nUse \"backctl backup ls\" to see the list of backups";
            } 
            $ok[1] = 1;
        } else {
            return $help;
        }
    }

    # The user and the number are mandatory
    if ($ok[0] && $ok[1]) {
        # Delete the backup
        my $user_dir = $config->{"BACKUP_DIR"} . ($config->{"BACKUP_DIR"} =~ /\/$/ ? "" : "/") . $user;
        my @backups = split '\n', `ls $user_dir | sort -r`;
        unlink "$user_dir/$backups[--$number]";
        return "Backup deleted successfully";
    } else {
        return $help;
    } 
}

sub get_date {
    my $date = shift;
    chomp $date;
    my @vals = split '-', $date;
    $vals[5] = substr $vals[5], 0, -8;
    foreach my $val (@vals) {
        if (length($val) == 1) {
            $val = "0" . $val;
        }
    }
    return $vals[2]."/".$vals[1]."/".$vals[0]." ".$vals[3].":".$vals[4].":".$vals[5];
}

1;

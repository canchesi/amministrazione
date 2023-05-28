package commands::backup;

use warnings;
use strict;
use Text::ASCIITable;
use Switch;
use JSON;
use File::Path;
use Thread;
use Time::HiRes qw(time);
require "./lib/utils.pm";
require "./scripts/zipper.pm";

no warnings 'experimental';

sub parse {
    my $connection = shift @_;
    my $command = shift @_ || "";

    my $help = "Usage: backup [COMMAND] [OPTIONS]\n" .
                "Perform a backup for a selected user or lists all the backups for a selected user.\n" .
                "Command: \n" .
                "  ls\t\t\tList all the backups for a selected user\n" .
                "  start\t\t\tStart a backup for a selected user\n";

    switch ($command) {
        case "ls" {
            return ls(@_);
        }
        case "start" {
            return start($connection, @_);
        }
        else {
            return $help;
        }
    }

}

sub ls {

    my $help = "Usage: backup ls [OPTIONS]\n" .
                "List all the backups recorded in the system.\n" .
                "Options: \n" .
                "  -u, --user\t\tUser for which to list the backups\n";
    my $json_data = utils::read_user_json();
    my $table = Text::ASCIITable->new({});
    $table->setCols("NAME", "DIRECTORIES", "DATES");
    my %users = (names => [], ids => []);

    foreach my $command (@_) {
        if ($command =~ /^(-u|--user)$/) {
            shift @_; my $user = shift @_;
            if ($user eq "" || $user =~ /^-.*/) {
                return $help;
            }
            @{$users{names}} = split ',', $user;
            for (my $i = 0; $i < scalar @{$users{names}}; $i++) {
                my $exists = utils::user_exists($users{names}[$i]);
                if ($users{names} =~ /^-.*/) {
                    return $help;
                } elsif ($exists == 2) {
                    return "User $users{names}[$i] does not exist in the system";
                } elsif ($exists == 1) {
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
    if (scalar @{$users{names}} == 0) {
        @{$users{names}} = keys $json_data->%*;
        for (my $i = 0; $i < scalar @{$users{names}}; $i++) {
            $users{names}[$i] = `id -un $users{names}[$i]`;
            $users{ids}[$i] = `id -u $users{names}[$i]`;
        }
    }
    @{$users{names}} = sort @{$users{names}};
    @{$users{ids}} = sort @{$users{ids}};
    chomp @{$users{names}};
    chomp @{$users{ids}};

    foreach (my $i = 0; $i < scalar @{$users{names}}; $i++) {
        my $user_dir = "/var/back-a-la/" . $users{ids}[$i]; chomp $user_dir;
        my @backups = `ls -t -l $user_dir | grep -v total | awk '{print \$9}'`; chomp @backups;
        my $dates = "";
        my $dirs = "";
        if (! -d $user_dir) {
            next;
        }
        
        foreach my $dir ($json_data->{$users{ids}[$i]}->{"directories"}->@*) {
            $dirs .= $dir . "\n";
        } chomp $dirs;
        foreach (my $i = 0; $i < scalar @backups-1; $i++) {
            $dates .= $i+1 . ")  " . get_date($backups[$i]) . "\n";
        } $dates .= scalar @backups . ") " . get_date($backups[scalar @backups-1]); chomp $dates;
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

    my $help = "Usage: backup start [OPTIONS]\n" .
                "Perform a backup for a selected list of users.\n" .
                "Options: \n" .
                "  -u, --user\t\tUser for which to perform the backup\n";

    foreach my $command (@_) {
        if ($command =~ /^(-u|--user)$/) {
            shift @_; $user = shift @_;
            @users = split ',', $user;
            for (my $i = 0; $i < scalar @users; $i++) {
                $users[$i] = `id -u $users[$i]`;
                my $exists = utils::user_exists($users[$i]);
                if ($user eq "" || $user =~ /^-.*/) {
                    return $help;
                } elsif ($exists == 2) {
                    return "User $user does not exist in the system";
                } elsif ($exists == 1) {
                    return "User $user does not exist in Back-a-la system";
                } elsif (`id -u $users[$i]` < 1000) {
                    return "Impossible to make a backup of a system user ($user)";
                }
            }
        } else {
            return $help;
        }
    }
    utils::send_message($connection, "Backup started. It may take a while, please wait...");
    my $time = time();
    $SIG{INT} = sub { utils::send_message($connection, "Backup interrupted. Back-a-la interrupted the connection", 1); };
    foreach my $user (@users) {
        push @threads, threads->create(\&zipper::zip, $user);
    }

    while ($stop < scalar @threads) {
        foreach my $thread (@threads) {
            if ($thread->is_joinable()) {
                my @res = $thread->join();
                if ($res[0] == 1) {
                    return "Backup failed for user $res[1] (zip failed, maybe not enough space)";
                } elsif ($res[0] == 2) {
                    return "Backup failed for user $res[1] (encryption failed)";
                }
                $stop++;
            } 
        }
    }

    return "All backups performed successfully. (" . (time() - $time). ")";
    $SIG{INT} = sub {};
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
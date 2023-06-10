package commands::restore;

use warnings;
use strict;
use Switch;
use JSON;
use utils;
use zipper;

no warnings 'experimental';

my $config = utils::read_config();

sub restore {
    my $connection = shift @_;
    my $user = "";
    my $number = "";
    my @ok = (0, 0);
    my $help = "Usage: restore [OPTIONS]\n" .
                "Perform a restore of a backup for a selected user\n".
                "from the 10 most recent backups.\n" .
                "More recent backups will be removed.\n" .
                "Options: \n" .
                "  -u, --user USER\t\tUser to restore backup for\n" .
                "  -n, --number\t\tNumber of the backup to restore, based on the list of backups\n " .
                "\t\t\tgiven by the \"backctl backup ls\" command\n";

    foreach my $command (@_) {
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
                return "Impossible to make a backup of a system user";
            }
            $ok[0] = 1;
        } elsif ($_[0] =~ /^(-n|--number)$/) {
            shift @_; $number = shift @_; chomp $number;
            if ($number eq "" || $number =~ /^-.*/) {
                return $help;
            } elsif ($number !~ /^([1-9]|10)$/ || $number == 0) {
                return "Invalid number. Please select a number between 1 and 10.\nUse \"backctl backup ls\" to see the list of backups";
            } 
            $ok[1] = 1;
        } else {
            return $help;
        }
    }

    if ($ok[0] && $ok[1]) {
        return restore_backup($connection, $user, $number);
    } else {
        return $help;
    } 
}

sub restore_backup {
    my $connection = shift @_;
    my $user = shift @_;
    my $number = (shift @_) - 1;

    utils::send_message($connection, "Restore started. It may take a while, please wait...");    
    $SIG{INT} = sub { utils::send_message($connection, "Restore interrupted. Back-a-la interrupted the connection", 1); };
    my $user_dir = $config->{"BACKUP_DIR"} . ($config->{"BACKUP_DIR"} =~ /\/$/ ? "" : "/") . $user;
    my @backups = split '\n', `ls $user_dir | sort -r`;

    if ($backups[0] eq "") {
        return "No backups found for user $user";
    }

    my $err = crypt::decrypt($backups[$number], $user);
    if ($err == 0) {
        $backups[$number] =~ s/\.enc//g;
        if (zip::extract($backups[$number], $user) == 0) {
            unlink "/tmp/." . $backups[$number];
            remove_older($user, $number);
            $SIG{INT} = sub {};
            return "Restore performed successfully";
        } else {
            unlink "/tmp/." . $backups[$number];
            return "Restore failed (unzip failed)";
        }
    } elsif ($err == 2) {
        return "Restore failed (backup does not exist)";
    } else {
        unlink "/tmp/." . $backups[$number];
        return "Restore failed (decryption failed)";
    }

}

sub remove_older {
    my $user_dir = $config->{"BACKUP_DIR"} . ($config->{"BACKUP_DIR"} =~ /\/$/ ? "" : "/") . shift @_;
    my $number = shift @_;
    my @backups = split '\n', `ls $user_dir | sort -r`;
    for (my $i = 0; $i < $number; $i++) {
        unlink "$user_dir/$backups[$i]";
    }
}

1;

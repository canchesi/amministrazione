
package commands::dirs;

use warnings;
use strict;
use Switch;
use JSON;
use utils;

no warnings 'experimental';

sub directory {
    my $help =  "Usage: backctl directory COMMAND [OPTIONS] DIR\n\n" .
                "Commands: \n" .
                "  add DIRECTORIES\tAdd a directory to the list of directories to be backed up\n" .
                "  del DIRECTORIES\tDelete a directory from the list of directories to be backed up\n" .
                "Options:\n" .
                "  -u, --user USER\t\tUser for which the directory is to be added or deleted";

    my $command = shift @_ || "";
    my $option = shift @_ || "";
    my $user = "";
    my @directories = ();
    my @old_directories = ();

    # The command is mandatory
    if ($command ne "add" && $command ne "del") {
        return $help;
    }

    # The option is mandatory
    if ($option eq "-u" || $option eq "--user") {
        $user = shift @_ || "";
    } else {
        return $help;
    }

    # Checks if the user exists
    my $user_id = `grep '^$user:' /etc/passwd | cut -d ':' -f 3`;
    if ($user_id eq "") {
        return "User does not exist in the system";
    }
    chomp $user_id;

    # Reads the user configuration file
    my $json_data = utils::read_user_json();

    if (! exists $json_data->{$user_id}) {
        return "User does not exist in Back-a-la system";
    }

    # Takes the directories
    @old_directories = @{$json_data->{$user_id}->{'directories'}};
    @directories = @_;
    
    # Acts according to the command
    if ($command eq "add") {
        # Adds the directories
        foreach my $directory (@directories) {
            if (! grep (/^$directory$/, @old_directories)) {
                push @old_directories, $directory;
            }
        }
        $json_data->{$user_id}->{'directories'} = \@old_directories;
    } elsif ($command eq "del") {
        # Deletes the directories
        my @new_directories = ();
        foreach my $old_directory (@old_directories) {
            if (! grep (/^$old_directory$/, @directories)) {
                push @new_directories, $old_directory;
            }
        }
        $json_data->{$user_id}->{'directories'} = \@new_directories;
    }

    # Updates the user configuration file
    open(my $json_file, '>', '/etc/back/users.json') or die $!;
    print $json_file JSON->new->ascii->pretty->encode($json_data);
    close($json_file);
    return "Directories updated successfully";
}
1;

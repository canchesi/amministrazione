
package commands::dirs;

use warnings;
use strict;
use Switch;
use JSON;
use utils;

no warnings 'experimental';

sub directory {
    my $help = "Usage: directory [OPTIONS]\n" .
                "Commands: \n" .
                "  add DIRECTORIES\tAdd a directory to the list of directories to be backed up\n" .
                "  del DIRECTORIES\tDelete a directory from the list of directories to be backed up\n" .
                "\nOptions:\n" .
                "  -u, --user USER\t\tUser for which the directory is to be added or deleted\n" .
                "  -h, --help\t\t\tDisplay this help and exit\n";

    my $command = shift @_ || "";
    my $option = shift @_ || "";
    my $user = "";
    my @directories = ();
    my @old_directories = ();

    if ($command ne "add" && $command ne "del") {
        return $help;
    }

    if ($option eq "-u" || $option eq "--user") {
        $user = shift @_ || "";
    } else {
        return $help;
    }
    my $user_id = `grep '^$user:' /etc/passwd | cut -d ':' -f 3`;
    if ($user_id eq "") {
        return "User does not exist in the system";
    }
    chomp $user_id;

    my $json_data = utils::read_user_json();

    if (! exists $json_data->{$user_id}) {
        return "User does not exist in Back-a-la system";
    }

    @old_directories = @{$json_data->{$user_id}->{'directories'}};
    @directories = @_;
    if ($command eq "add") {
        foreach my $directory (@directories) {
            if (! grep (/^$directory$/, @old_directories)) {
                push @old_directories, $directory;
            }
        }
        $json_data->{$user_id}->{'directories'} = \@old_directories;
    } elsif ($command eq "del") {
        my @new_directories = ();
        foreach my $old_directory (@old_directories) {
            if (! grep (/^$old_directory$/, @directories)) {
                push @new_directories, $old_directory;
            }
        }
        $json_data->{$user_id}->{'directories'} = \@new_directories;
    }

    open(my $json_file, '>', '/etc/back/users.json') or die $!;
    print $json_file JSON->new->ascii->pretty->encode($json_data);
    close($json_file);
    return "Directories updated successfully";
}
1;
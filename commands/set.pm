package commands::set;

use warnings;
use strict;
use Switch;
use JSON;
use utils;

no warnings 'experimental';

sub set {
    my $help =  "Usage: backctl set [OPTIONS]\n\n" .
                "Set the period for a user's automatic backup.\n" .
                "  -u, --user USER\t\t\tUser to set the backup period for\n" .
                "  -t, --time TIME\t\t\tSet the backup period in cron format";
    my $user = "";
    my $time = "";
    my $option = "";
    my @ok = (0, 0);
    
    # Parse options
    for (my $i = 0; $i < 2; $i++) {
        $option = shift @_;
        if ($option =~ /^-/) {
            # Take the user
            if ($option eq "-u" || $option eq "--user") {
                $user = shift @_;
                $ok[0] = 1;
            } elsif ($option eq "-t" || $option eq "--time") {
                # Take the time in cron format
                for (my $i = 0; $i < 5; $i++) {
                    $time .= shift @_;
                    if ($i < 4) {
                        $time .= " ";
                    }
                }
                if (!check_cron($time)) {
                    return "Time interval must be in cron format. Check it out";
                }
                $ok[1] = 1;
            } else {
                return $help;
            }
        } else {
            return $help;
        }
    }

    # User and time are mandatory
    if (!$ok[0] || !$ok[1]) {
        return $help;
    }

    # Check if the user exists
    if ($user eq "") {
        return "No user given";
    }
    my $user_id = `grep '^$user:' /etc/passwd | cut -d ':' -f 3`;
    if ($user_id eq "") {
        return "User does not exist in the system";
    }
    chomp $user_id;

    # Reads the user configuration file
    my $json_data = utils::read_user_json();

    if (! exists $json_data->{$user_id}) {
        return "User does not exist in Back-a-la system";
    } elsif (sub_cron($time, $user) != 0) {
        # Set the cron job
        return "Error while setting cron"
    } else {
        $json_data->{$user_id}->{"period"} = $time;
        open(my $json_file, '>', '/etc/back/users.json') or die $!;
        print $json_file JSON->new->ascii->pretty->encode($json_data);
        close($json_file);
        return "User's backup period set successfully";
    }


}

sub check_cron {
    # Regex to check cron format
    return $_[0] =~ /^(\*|\*\/(0?[1-9]|[1-5]\d)|0[1-9]|[1-5]\d|\d)\ (\*|(\*\/)?(0?[1-9]|1\d|2[0-3])|[1-2][0-3]|\d)\ (\*|(\*\/)?((0?|[1-2])[0-9]|3[01])|3[0-1])\ ((JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC|(\*\/)?(0?[1-9]|1[0-2]))|\*)\ (MON|TUE|WED|THU|FRI|SAT|SUN|\*|(\*\/)?([0-6]))$/;
}

sub sub_cron {
    my $cron = shift @_;
    my $user = shift @_;
    my $start = `grep $user /etc/cron.d/back-a-la | cut -d ' ' -f 1`;

    $cron =~ s/\//\\\//g;
    if (substr($start, 0, 1) eq "#") {
        $cron = "#" . $cron;
    }
    # Replace the cron job
    if (system("ssed -R -i '/$user/ s/.*(?=root)/$cron /' /etc/cron.d/back-a-la") != 0) {
        return 1;
    } else {
        return 0;
    }
}
1;

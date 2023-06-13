package commands::user;

use warnings;
use strict;
use Text::ASCIITable;
use Switch;
use JSON;
use utils;

no warnings 'experimental';

my $config = utils::read_config();

# Parse the command
sub parse {
    my $command = shift @_ || "";
    my $help = "Usage: backctl user COMMAND [OPTIONS]\n\n" .
               "Commands: \n" .
               "  ls\t\t\tList all the users for which a backup is or can be performed\n" .
               "  add\t\t\tAdd a user to the list of users for which a backup is or can be performed\n" .
               "  del\t\t\tDelete a user from the list of users for which a backup is or can be performed\n" .
               "  up\t\t\tActivate backup for a user\n" .
               "  down\t\t\tDeactivate backup for a user";

    switch ($command) {
        case "ls" {
            return ls(@_);
        }
        case "add" { 
            my $err = add(@_);
            switch ($err) {
                case 0 { return "User added successfully"; }
                case 1 { return "No user given"; }
                case 2 { return "User does not exist in the system"; }
                case 3 { return "Impossible to add a system user"; }
                case 4 { return "User already exists"; }
                case 5 { return "Error while creating cron configuration"; }
                else { return $err; }
            }
        }
        case "del" {
            my $err = del(@_);
            switch ($err) {
                case 0 { return "User deleted successfully"; }
                case 1 { return "No user given"; }
                case 2 { return "User does not exist in the system"; }
                case 3 { return "User does not exist in Back-a-la system"; }
                case 4 { return "Error while deleting cron configuration"; }
                else { return $err; }
            }
        }
        case "up" {
            my $err = up(@_);
            switch ($err) {
                case 0 { return "User activated successfully"; }
                case 1 { return "No user given"; }
                case 2 { return "User does not exist in the system"; }
                case 3 { return "User does not exist in Back-a-la system"; }
                case 4 { return "User's backup already active"; }
                else { return $err; }
            }
        }
        case "down" {
            my $err = down(@_);
            switch ($err) {
                case 0 { return "User deactivated successfully"; }
                case 1 { return "No user given"; }
                case 2 { return "User does not exist in the system"; }
                case 3 { return "User does not exist in Back-a-la system"; }
                case 4 { return "User's backup already inactive"; }
                case 5 { return "Error during backup deactivation"; }
                else { return $err; }
            }
        }
        else { return $help; }
    }
}

# Lists all the users for which a backup is or can be performed
sub ls {
    # Requires no arguments
    if (scalar(@_)) {
        return  "Usage: backctl user ls\n\n" .
                "List all the users for which a backup is or can be performed.\n" .
                "It does not accept any option.";
    }

    my @ids = ();
    my $json_data = utils::read_user_json();
    my $table = Text::ASCIITable->new({});

    # Prepare the table
    $table->setCols("USER", "NAME", "DIRECTORIES", "CRON", "ACTIVE");

    # Get the list of users
    foreach my $user (keys $json_data->%*) {
        push @ids, $user;
    }
    @ids = sort @ids;
    
    # Add the users to the table
    foreach my $user (@ids) {
        # Takes the directories from the configuration file
        my $directories = join("\n", $json_data->{$user}->{"directories"}->@*);
        # Takes the period from the configuration file
        my $period = $json_data->{$user}->{"period"};
        # Takes the user name from the system
        my $name = `grep 'x:$user:' /etc/passwd | cut -d ':' -f 1`;
        # Add row to the table
        $table->addRow($user, $name, $directories, $period, $json_data->{$user}->{"active"});
        $table->addRowLine();
    }
    chomp $table;
    return $table;
}

# Adds a user to the list of users for which a backup is or can be performed
sub add {
    my $user = shift @_ || "";
    my $help =  "Usage: backctl user add USER\n\n" .
                "Add a user to the list of users for which a backup is or can be performed.\n" .
                "It does not accept any option.";
    my $json_data = utils::read_user_json();

    # Requires no arguments (check if the user is a flag)
    if ($user =~ /^-.*/) {
        return $help;
    }

    # Check if the user exists
    if ($user eq "") {
        return 1;
    }
    my $user_id = `grep '^$user:' /etc/passwd | cut -d ':' -f 3`;

    if ($user_id eq "") {
        return 2;
    } elsif ($user_id + 0 < 1000) {
        return 3;
    }
    chomp $user_id;
    
    # Check if the user already exists
    if (exists $json_data->{$user_id}) {
        return 4;  
    } elsif (system("echo '#" . $config->{'DEFAULT_PERIOD'} . " root backctl backup start -u $user\n' >> /etc/cron.d/back-a-la") != 0) {
        # Add the cron configuration
        return 5;
    } else { 
        # Add the user to the Back-a-la system
        $json_data->{$user_id} = {
            "directories" => [],
            "active" => "false",
            "period" => $config->{'DEFAULT_PERIOD'}
        };
        open(my $json_file, '>', '/etc/back/users.json') or die $!;
        print $json_file JSON->new->ascii->pretty->encode($json_data);
        close($json_file);
        # Create the user's backup directory
        File::Path::make_path($config->{'BACKUP_DIR'} . ($config->{'BACKUP_DIR'} =~ /\/$/ ? "" : "/") . $user_id);
        return 0;
    }
}

sub del {
    my $user = shift @_ || "";
    my $help =  "Usage: backctl user del USER\n\n" .
                "Delete a user from the list of users for which a backup is or can be performed.\n" .
                "It does not accept any option.";
    my $not_exist = undef;
    my $json_data = utils::read_user_json();

    # Requires no arguments
    if ($user =~ /^-.*/) {
        return $help;
    }

    # Check if the user exists
    if ($user eq "") {
        return 1;
    }
    my $user_id = `grep '^$user:' /etc/passwd | cut -d ':' -f 3`;
    if ($user_id eq "") {
        return 2;
    }
    chomp $user_id;

    # Check if the user exists in the Back-a-la system
    if (! exists $json_data->{$user_id}) {
        return 3;
    } elsif (system("sed -i '/$user/,+1d' /etc/cron.d/back-a-la;") != 0) {
        # Remove the cron configuration
        return 5;
    } else {
        # Delete the user from the Back-a-la system
        delete $json_data->{$user_id};
        open(my $json_file, '>', '/etc/back/users.json') or die $!; 
        truncate $json_file, 0;
        print $json_file JSON->new->ascii->pretty->encode($json_data);
        close($json_file);
        return 0;
    }
}

sub up {
    my $user = shift @_ || "";
    my $help =  "Usage: backctl user up USER\n\n" .
                "Activate backup for a user.\n" .
                "It does not accept any option.";

    # Requires no arguments
    if ($user =~ /^-.*/) {
        return $help;
    }

    # Check if the user exists
    if ($user eq "") {
        return 1;
    }
    my $user_id = `grep '^$user:' /etc/passwd | cut -d ':' -f 3`;
    if ($user_id eq "") {
        return 2;
    }
    chomp $user_id;

    # Read the user configuration file
    my $json_data = utils::read_user_json();

    # Check if the user exists in the Back-a-la system
    if (! exists $json_data->{$user_id}) {
        return 3;
    } elsif ($json_data->{$user_id}->{"active"} eq "true") {
        return 4;
    } elsif (system("sed -i '/$user/ s/^#//' /etc/cron.d/back-a-la") != 0) {
        # Remove the comment character from the cron job for the user's automatic backup
        return 5;
    } else {
        $json_data->{$user_id}->{"active"} = "true";
        open(my $json_file, '>', '/etc/back/users.json') or die $!;
        print $json_file JSON->new->ascii->pretty->encode($json_data);
        close($json_file);
        return 0;
    }
}

sub down {
    my $user = shift @_ || "";
    my $help =  "Usage: user down [USER]\n\n" .
                "Deactivate backup for a user.\n" .
                "It does not accept any option.";

    # Requires no arguments
    if ($user =~ /^-.*/) {
        return $help;
    }

    # Check if the user exists
    if ($user eq "") {
        return 1;
    }
    my $user_id = `grep '^$user:' /etc/passwd | cut -d ':' -f 3`;
    if ($user_id eq "") {
        return 2;
    }
    chomp $user_id;

    # Read the user configuration file
    my $json_data = utils::read_user_json();

    # Check if the user exists in the Back-a-la system
    if (! exists $json_data->{$user_id}) {
        return 3;
    } elsif ($json_data->{$user_id}->{"active"} eq "false") {
        return 4;
    } elsif (system("sed -i '/$user/ s/^/#/' /etc/cron.d/back-a-la") != 0) {
        # Comments the cron job for the user's automatic backup
        return 5;
    } else {
        $json_data->{$user_id}->{"active"} = "false";
        open(my $json_file, '>', '/etc/back/users.json') or die $!;
        print $json_file JSON->new->ascii->pretty->encode($json_data);
        close($json_file);
        return 0;
    }
}
1;

package commands::user;

use warnings;
use strict;
use Text::ASCIITable;
use Switch;
use JSON;
require "./lib/utils.pm";

no warnings 'experimental';

sub parse {
    my $command = shift @_ || "";
    my $help = "Usage: user [COMMAND] [OPTIONS]\n" .
               "Commands: \n" .
               "  ls\t\t\tList all the users for which a backup is or can be performed\n" .
               "  add\t\t\tAdd a user to the list of users for which a backup is or can be performed\n" .
               "  del\t\t\tDelete a user from the list of users for which a backup is or can be performed\n" .
               "  up\t\t\tActivate backup for a user\n" .
               "  down\t\t\tDeactivate backup for a user\n";

    switch ($command) {
        case "ls" {
            return ls(@_);
        }
        case "add" { 
            my $err = add(@_);
            switch ($err) {
                case 0 { return "User added successfully\n"; }
                case 1 { return "No user given\n"; }
                case 2 { return "User does not exist in the system\n"; }
                case 3 { return "Impossible to add a system user\n"; }
                case 4 { return "User already exists\n"; }
                else { return $err; }
            }
        }
        case "del" {
            my $err = del(@_);
            switch ($err) {
                case 0 { return "User deleted successfully\n"; }
                case 1 { return "No user given\n"; }
                case 2 { return "User does not exist in the system\n"; }
                case 3 { return "User does not exist in Back-a-la system\n"; }
                else { return $err; }
            }
        }
        case "up" {
            my $err = up(@_);
            switch ($err) {
                case 0 { return "User activated successfully\n"; }
                case 1 { return "No user given\n"; }
                case 2 { return "User does not exist in the system\n"; }
                case 3 { return "User does not exist in Back-a-la system\n"; }
                case 4 { return "User's backup already active\n"; }
                else { return $err; }
            }
        }
        case "down" {
            my $err = down(@_);
            switch ($err) {
                case 0 { return "User deactivated successfully\n"; }
                case 1 { return "No user given\n"; }
                case 2 { return "User does not exist in the system\n"; }
                case 3 { return "User does not exist in Back-a-la system\n"; }
                case 4 { return "User's backup already inactive\n"; }
                case 5 { return "Error during backup deactivation\n"; }
                else { return $err; }
            }
        }
        else { return $help; }
    }
}

sub ls {
    my %options = ( # AGGIUNGERE QUA FLAGS PER LS
        all => 0,
        quiet => 0
    );
    foreach my $option (@_) {
        switch ($option) {      # AGGIUNGERE QUA LE MODIFICHE AI FLAG PER LS
            case qr/^(-a|--all)$/ { $options{all} = 1; }
            case qr/^(-q|--quiet)$/ { $options{quiet} = 1; }
            else { return "Usage: user ls [OPTION]\n" .
                "List all the users for which a backup is or can be performed.\n" .
                "  -a, --all\t\t\tList all the users, even the inactive ones\n" .
                "  -q, --quiet\t\t\tPrint only the users' ids\n" .
                "  -h, --help\t\t\tDisplay this help and exit\n";
            }
        }
    }

    my @ids = ();
    my $json_data = utils::read_user_json();
    my $table = Text::ASCIITable->new({});
    my $quiet = undef;

    if (!$options{quiet}) {
        $table->setCols("USER", "NAME", "DIRECTORIES", "ACTIVE");
    }

    foreach my $user (keys $json_data->%*) {
        push @ids, $user;
    }
    @ids = sort @ids;
    foreach my $user (@ids) {
        my $directories = join("\n", $json_data->{$user}->{"directories"}->@*);
        my $name = `grep 'x:$user:' /etc/passwd | cut -d ':' -f 1`;
        if ($options{all} || $json_data->{$user}->{"active"} eq "true") {
            if ($options{quiet}) {
                $quiet .= "$user\n";
            } else {
                $table->addRow($user, $name, $directories, $json_data->{$user}->{"active"});
                $table->addRowLine();
            }
        }
    }
    if ($options{quiet}) {
        chomp $quiet;
        return $quiet;
    }
    chomp $table;
    return $table;
}

sub add {
    my $user = shift @_ || "";
    my $help = "Usage: user add [USER]\n" .
            "Add a user to the list of users for which a backup is or can be performed.\n" .
            "  It does not accept any option.\n" .
            "  -h, --help\t\t\tDisplay this help and exit\n";
    my $not_exist = undef;
    my $json_data = utils::read_user_json();

    if ($user =~ /^-.*/) {
        return $help;
    }

    if ($user eq "") {
        return 1;
    }
    $user = `grep '^$user:' /etc/passwd | cut -d ':' -f 3`;

    if ($user eq "") {
        return 2;
    } elsif ($user + 0 < 1000) {
        return 3;
    }
    chomp $user;

    if (exists $json_data->{$user}) {
        return 4;  
    } else {
        $json_data->{$user} = {
            "directories" => [],
            "active" => "false"
        };
        open(my $json_file, '>', '/etc/back/users.json') or die $!;
        print $json_file JSON->new->ascii->pretty->encode($json_data);
        close($json_file);
        File::Path::make_path("/var/back-a-la/$user");
        return 0;
    }
}

sub del {
    my $user = shift @_ || "";
    my $help = "Usage: user del [USER]\n" .
            "Delete a user from the list of users for which a backup is or can be performed.\n" .
            "  It does not accept any option.\n" .
            "  -h, --help\t\t\tDisplay this help and exit\n";
    my $not_exist = undef;
    my $json_data = utils::read_user_json();

    if ($user =~ /^-.*/) {
        return $help;
    }

    if ($user eq "") {
        return 1;
    }
    $user = `grep '^$user:' /etc/passwd | cut -d ':' -f 3`;
    if ($user eq "") {
        return 2;
    }
    chomp $user;

    if (! exists $json_data->{$user}) {
        return 3;
    } else {
        delete $json_data->{$user};
        open(my $json_file, '>', '/etc/back/users.json') or die $!; 
        truncate $json_file, 0;
        print $json_file JSON->new->ascii->pretty->encode($json_data);
        close($json_file);
        return 0;
    }
}

sub up {
    my $user = shift @_ || "";
    my $help = "Usage: user up [USER]\n" .
            "Activate backup for a user.\n" .
            "  It does not accept any option.\n" .
            "  -h, --help\t\t\tDisplay this help and exit\n";

    if ($user =~ /^-.*/) {
        return $help;
    }

    if ($user eq "") {
        return 1;
    }
    my $user_id = `grep '^$user:' /etc/passwd | cut -d ':' -f 3`;
    if ($user_id eq "") {
        return 2;
    }
    chomp $user_id;

    my $json_data = utils::read_user_json();

    if (! exists $json_data->{$user_id}) {
        return 3;
    } elsif ($json_data->{$user_id}->{"active"} eq "true") {
        return 4;
    } elsif (system("sed -i --follow-symlink '/$user/ s/^#//' /etc/cron.d/back-a-la") != 0) {
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
    my $help = "Usage: user down [USER]\n" .
            "Deactivate backup for a user.\n" .
            "  It does not accept any option.\n" .
            "  -h, --help\t\t\tDisplay this help and exit\n";

    if ($user =~ /^-.*/) {
        return $help;
    }

    if ($user eq "") {
        return 1;
    }
    my $user_id = `grep '^$user:' /etc/passwd | cut -d ':' -f 3`;
    if ($user_id eq "") {
        return 2;
    }
    chomp $user_id;

    my $json_data = utils::read_user_json();

    if (! exists $json_data->{$user_id}) {
        return 3;
    } elsif ($json_data->{$user_id}->{"active"} eq "false") {
        return 4;
    } elsif (system("sed -i --follow-symlink '/$user/ s/^/#/' /etc/cron.d/back-a-la") != 0) {
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
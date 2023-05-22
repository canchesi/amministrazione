package commands::users;

use warnings;
use strict;
use Text::Table;
use Switch;
use JSON;

no warnings 'experimental';
my @accepted_commands = ("ls");

sub parse {
    my $command = shift @_ || "";

    switch ($command) {
        case "ls" { return ls(@_); }
        case "" { return "No command given for \"users\"\n"; }
        else { return "Command not accepted in \"users\" functionalities: $command\n"; exit 1; }
    }
}

sub ls {
    my @accepted_options = ("-a");  # AGGIUNGERE QUA OPZIONI PER LS
    my %options = (all => 0);       # AGGIUNGERE QUA FLAGS PER LS
    foreach my $option (@_) {
        switch ($option) {      # AGGIUNGERE QUA LE MODIFICHE AI FLAG PER LS
            case /^(-a|--all)$/ { $options{all} = 1; } 
            else { return "Option not accepted in \"users ls\" funcionalities: $option\n"; exit 1; }
        }
    }
    my @ids = ();

    open(my $json_file, '<', '/etc/back/users.json') or die $!;
    my $json_text = join('', <$json_file>);
    close($json_file);
    my $json_data = decode_json($json_text);

    my $table = Text::Table->new("USER", "NAME", "DIRECTORIES", "ACTIVE");
    foreach my $user (keys $json_data->%*) {
        push @ids, $user;
    }
    @ids = sort @ids;
    foreach my $user (@ids) {
        my $directories = join(",\n", $json_data->{$user}->{"directories"}->@*);
        my $name = `grep 'x:$user:' /etc/passwd | cut -d ':' -f 1`;
            if ($options{all} || $json_data->{$user}->{"active"} eq "true") {
                $table->add($user, $name, $directories, $json_data->{$user}->{"active"});
            }
    }
    return $table;
}

sub add {
    my $user = shift @_;

    open(my $json_file, '<', '/etc/back/users.json') or die $!;
    my $json_text = join('', <$json_file>);
    close($json_file);
    my $json_data = decode_json($json_text);

    if (exists $json_data->{$user}) {
        return "User already exists\n";
        exit 1;
    } else {
        $json_data->{$user} = {
            "directories" => [],
            "active" => "false"
        };
        open(my $json_file, '>', '/etc/back/users.json') or die $!;
        print $json_file encode_json($json_data);
        close($json_file);
    }
}
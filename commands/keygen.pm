package commands::keygen;

use crypt;
use utils;
use warnings;
use strict;
use Switch;
use JSON;
use File::Slurp;

no warnings 'experimental';

sub keygen {
    my $connection = shift @_;
    my $option = shift @_ || "";
    my $help =  "Usage: backctl keygen [OPTIONS]\n\n" .
                "Generates RSA keys for the backup system\n" .
                "Options:\n" .
                "  -p, --pass [PASSPHRASE]  Generates the keys with the given passphrase\n" .
                "                           No spaces and hyphens allowed. Cannot be used with --passfile\n" .
                "  --passfile [FILE]        Generates the keys with the passphrase contained in the given file.\n" .
                "                           No spaces and hyphens allowed. Cannot be used with -p/--pass\n" .
                "  -h, --help               Displays this help and exit";
    my $pass = "";
    my @msg = ();
    
    # Parse the options
    switch ($option) {
        case qr/^(-p|--pass)$/ {
            $pass = shift @_ || "";
            if ($pass eq "" || $pass =~ /^-.*/ ||grep(/^(--passfile)$/, @_)) {
                return $help;
            }
        }
        case qr/^(--passfile)$/ {
            my $passfile = shift @_ || "";
            if ($passfile eq "" || grep(/^(-p|--pass)$/, @_)) {
                return $help;
            }
            if (! -f $passfile) {
                return "File not found";
            }
            open my $fh, "<", $passfile;
            $pass = read_file($fh);
            chomp $pass; 
            if ($pass =~ /^-.*/) {
                return $help;
            }
            close $fh;
        }
        case qr/^(-h|--help)$/ {
            return $help;
        }
    }
    
    my %keys_info = ();
    # Get the passphrase
    $keys_info{"Passphrase"} = $pass;
    chomp $keys_info{"Passphrase"};

    if (length $keys_info{"Passphrase"} < 5 && $keys_info{"Passphrase"} ne "") {
        utils::send_message($connection, "Passphrase too short. Minimum five characters", 1);
        return "1";
    }


    # Creates the directories for the keys if they do not exist
    if (! -d "/etc/back/keys/old") {
        File::Path::mkpath("/etc/back/keys/old", 0, 0700);
    }

    # Generates the passphrase
    utils::send_message($connection, "Generating passphrase...");
    system("openssl rand -base64 128 > /etc/back/keys/passphrase.tmp 2> /dev/null");

    # Renames temporaneously the old passphrase
    File::Find::find(sub {
        if ($_ =~ /(back|back.pub|\.master_key|passphrase)$/) {
            rename $_, $_ . ".old";
        }
    }, "/etc/back/keys");

    # Generates the RSA keys
    utils::send_message($connection, "Generating RSA key...");
    my $command = 'ssh-keygen -f /etc/back/keys/back -b 2048 -m PEM -t rsa -N "'. $keys_info{"Passphrase"} . '" > /dev/null';

    # If generating the keys is successful
    if (system($command) == 0) { 

        # Generates the PEM public key
        $command = "ssh-keygen -f /etc/back/keys/back.pub -b 2048 -t rsa -e -m PEM";
        if ($keys_info{"Passphrase"} ne "") {
            $command .= " -N " . $keys_info{"Passphrase"};
        }
        $command .= " > /etc/back/keys/back.pub.pem 2> /dev/null";

        # If generating the PEM public key fails
        if (system($command) != 0) { 
            # Restores the old passphrase
            File::Find::find(sub {
                if ($_ =~ /(back|back.pub|\.master_key|passphrase)$/) {
                    rename $_ , substr($_, 0, -4);
                }
            }, "/etc/back/keys");

            return "Error generating RSA key. If there is an old key, it has been restored.";
        }
        rename "/etc/back/keys/back.pub.pem", "/etc/back/keys/back.pub";

        # Creates the file with the passphrase in clear but with 0000 permissions
        open(my $file, '>', "/etc/back/keys/.master_key") or die $!;
        print $file $keys_info{"Passphrase"};
        close($file);
        chmod 0000, "/etc/back/keys/.master_key";
    
    } else {
        # If the generation of the keys fails
        # restores the old passphrase
        File::Find::find(sub {
                if ($_ =~ /(back|back.pub|\.master_key)\.old$/) {
                rename $_ , substr($_, 0, -4);
            }
        }, "/etc/back/keys");

        return "Error generating RSA key. If there is an old key, it has been restored.";
    }

    # If the generation of the keys is successful, deletes the old keys
    rename "/etc/back/keys/back.old", "/etc/back/keys/old/back.old";
    rename "/etc/back/keys/back.pub.old", "/etc/back/keys/old/back.pub.old";
    rename "/etc/back/keys/.master_key.old", "/etc/back/keys/old/.master_key.old";
    rename "/etc/back/keys/passphrase.old", "/etc/back/keys/old/passphrase.old";

    utils::send_message($connection, "RSA key generated");

    # Creates the file with the encrypted passphrase (Digital Envelope)
    system("openssl pkeyutl -encrypt -pubin -inkey /etc/back/keys/back.pub -in /etc/back/keys/passphrase.tmp -out /etc/back/keys/passphrase 2> /dev/null");
    unlink "/etc/back/keys/passphrase.tmp";
    utils::send_message($connection, "Passphrase generated", 1);

}
1;
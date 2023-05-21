package crypt;

use strict;
use warnings;
use File::Path;
use File::Copy;
use File::Find;
use File::Slurp;
use Crypt::OpenSSL::RSA;
use feature qw(say);


sub generate_keys {

    my %keys_info = ();

    # Chiede la passphrase per le chiavi RSA
    say "Insert RSA key passphrase (minimum five characters) []: ";
    system("stty -echo");
    $keys_info{"Passphrase"} = <STDIN>;
    system("stty echo");
    chomp $keys_info{"Passphrase"};
    if ($keys_info{"Passphrase"} eq "") {
        $keys_info{"Passphrase"} = "";
    }

    say "Insert RSA key passphrase again []: ";
    system("stty -echo");
    my $passphrase = <STDIN>;
    system("stty echo");
    chomp $passphrase;
    if ($passphrase ne $keys_info{"Passphrase"}) {
        say "Passphrase mismatch";
        exit 1;
    }


    # Crea le directories per le chiavi se non esistono 
    if (! -d "/etc/back/keys") {
        File::Path::mkpath("/etc/back/keys", 0, 2700);
    }
    if (! -d "/etc/back/keys/old") {
        File::Path::mkpath("/etc/back/keys/old", 0, 2700);
    }

    # Genera la passphrase
    system("openssl rand -base64 128 > /etc/back/keys/passphrase.tmp 2> /dev/null");
    say "Passphrase generated";
 
    # Rinomina le chiavi precedenti temporaneamente 
    File::Find::find(sub {
        if ($_ =~ /(back|back.pub|\.master_key|passphrase)$/) {
            rename $_, $_ . ".old";
        }
    }, "/etc/back/keys");

    # Genera le chiavi RSA
    say "Generating RSA key...";
    my $command = "ssh-keygen -f /etc/back/keys/back -b 2048 -m PEM -t rsa ";
    if ($keys_info{"Passphrase"} ne "") {
        $command .= "-N " . $keys_info{"Passphrase"};
    }
    $command .= " > /dev/null";
    
    if (system($command) == 0) { # Se la generazione delle chiavi è andata a buon fine

        # Genera la chiave pubblica in formato PEM
        $command = "ssh-keygen -f /etc/back/keys/back.pub -b 2048 -t rsa -e -m PEM";
        if ($keys_info{"Passphrase"} ne "") {
            $command .= " -N " . $keys_info{"Passphrase"};
        }
        $command .= " > /etc/back/keys/back.pub.pem 2> /dev/null";

        if (system($command) != 0) { # Se la generazione della chiave pubblica PEM è fallita

            # Ripristina le chiavi precedenti e termina
            File::Find::find(sub {
        if ($_ =~ /(back|back.pub|\.master_key|passphrase)$/) {
                    rename $_ , substr($_, 0, -4);
                }
            }, "/etc/back/keys");

            say "Error generating RSA key. If there is an old key, it has been restored.";
            exit 1;        
        }
        rename "/etc/back/keys/back.pub.pem", "/etc/back/keys/back.pub";

        # Crea il file con la passphrase in chiaro ma con permessi 0000
        open(my $file, '>', "/etc/back/keys/.master_key") or die $!;
        print $file $keys_info{"Passphrase"};
        close($file);
        chmod 0000, "/etc/back/keys/.master_key";
    
    } else { # Se la generazione delle chiavi è fallita

        # Ripristina le chiavi precedenti e termina
        File::Find::find(sub {
                if ($_ =~ /(back|back.pub|\.master_key)\.old$/) {
                rename $_ , substr($_, 0, -4);
            }
        }, "/etc/back/keys");

        say "Error generating RSA key. If there is an old key, it has been restored.";
        exit 1;
    }

    # Se la generazione delle chiavi è andata a buon fine, elimina le chiavi precedenti    
    rename "/etc/back/keys/back.old", "/etc/back/keys/old/back.old";
    rename "/etc/back/keys/back.pub.old", "/etc/back/keys/old/back.pub.old";
    rename "/etc/back/keys/.master_key.old", "/etc/back/keys/old/.master_key.old";
    rename "/etc/back/keys/passphrase.old", "/etc/back/keys/old/passphrase.old";

    say "RSA key generated";

    # Crea il file con la passphrase cifrata (Digital Envelope)
    system("openssl pkeyutl -encrypt -pubin -inkey /etc/back/keys/back.pub -in /etc/back/keys/passphrase.tmp -out /etc/back/keys/passphrase 2> /dev/null");
    unlink "/etc/back/keys/passphrase.tmp";
    say "Passphrase encrypted";

}

# Cifra un file con AES-256-CBC
sub encrypt {
    my $name = $_[0];
    system("openssl enc -aes-256-cbc -pbkdf2 -in " . $name . " -out " . $name . ".enc -pass pass:" . get_passphrase() . " 2> /dev/null");
    unlink $name;
}

# Decifra un file con AES-256-CBC
sub decrypt {
    my $name = $_[0];
    system("openssl enc -aes-256-cbc -pbkdf2 -d -in " . $name . " -out " . substr($name, 0, -4) . " -pass pass:" . get_passphrase() . " 2> /dev/null");
    unlink $name;
}

# Ottiene la passphrase per le chiavi RSA
sub get_passphrase {

    open(my $file, '<', "/etc/back/keys/.master_key") or die $!;
    my $master_key = read_file($file);
    close($file);
    
    open( $file, '<', "/etc/back/keys/back.pub") or die $!;
    my $public = read_file($file);
    close($file);

    system("openssl pkeyutl -decrypt -inkey /etc/back/keys/back -in /etc/back/keys/passphrase -passin pass:" . $master_key . " -out /tmp/passphrase 2> /dev/null");
    open($file, '<', "/tmp/passphrase") or die $!;
    my $passphrase = read_file($file);
    close($file);
    unlink "/tmp/passphrase";

    $passphrase =~ s/\n//g;
    return $passphrase;

}
1;
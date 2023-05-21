package crypt;

use strict;
use warnings;
use File::Path;
use File::Copy;
use File::Find;
use File::Slurp;
use Crypt::OpenSSL::RSA;
use feature qw(say);

my %keys_info = ();

sub generate_keys {

    say "Insert RSA key passphrase []: ";
    $keys_info{"Passphrase"} = <STDIN>;
    chomp $keys_info{"Passphrase"};
    if ($keys_info{"Passphrase"} eq "") {
        $keys_info{"Passphrase"} = "";
    }

    say "Insert RSA key passphrase again []: ";
    my $passphrase = <STDIN>;
    chomp $passphrase;
    if ($passphrase ne $keys_info{"Passphrase"}) {
        say "Passphrase mismatch";
        exit 1;
    } elsif ($keys_info{"Passphrase"} ne "") {
        $keys_info{"Passphrase"} = $keys_info{"Passphrase"};
    }

    if (! -d "/etc/back/keys") {
        File::Path::mkpath("/etc/back/keys", 0, 2700);
    }
    if (! -d "/etc/back/keys/old") {
        File::Path::mkpath("/etc/back/keys/old", 0, 2700);
    }

    system("openssl rand -base64 128 > /etc/back/keys/passphrase.tmp");

    say "Generating RSA key...";
    $File::Find::prune = 1;  # Don't recurse.
    File::Find::find(sub {
        if ($_ =~ /.*\.(key|pub)/) {
            File::Copy::copy("/etc/back/keys/" . $_, "/etc/back/keys/" . $_ . ".old");
            unlink $_;
        }
    }, "/etc/back/keys");

    my $command = "openssl genrsa -out /etc/back/keys/back.key ";
    if ($keys_info{"Passphrase"} ne "") {
        $command .= "-passout pass:" . $keys_info{"Passphrase"} . " ";
    }
    $command .= "2048";
    say $command;
    if (system($command) == 0) {
        $command = "openssl rsa -in /etc/back/keys/back.key ";
        if ($keys_info{"Passphrase"} ne "") {
            $command .= "-passin pass:" . $keys_info{"Passphrase"} . " ";
        }
        $command .= " -out /etc/back/keys/back.pub -pubout";
        if (system($command) != 0) {
            unlink "/etc/back/keys/back.key";
            if (-e "/etc/back/keys/back.key.old") {
                File::Copy::copy("/etc/back/keys/back.key.old", "/etc/back/keys/back.key");
                unlink "/etc/back/keys/back.key.old";
            }
            if (-e "/etc/back/keys/back.pub.old") {
                File::Copy::copy("/etc/back/keys/back.pub.old", "/etc/back/keys/back.pub");
                unlink "/etc/back/keys/back.pub.old";
                say "Error generating RSA key. Old keys restored.";
            }
            
            say "Error generating RSA key";
            exit 1;
        }
    } else {
        if (-e "/etc/back/keys/back.key.old") {
            File::Copy::copy("/etc/back/keys/back.key.old", "/etc/back/keys/back.key");
            unlink "/etc/back/keys/back.key.old";
        }
        if (-e "/etc/back/keys/back.pub.old") {
            File::Copy::copy("/etc/back/keys/back.pub.old", "/etc/back/keys/back.pub");
            unlink "/etc/back/keys/back.pub.old";
            say "Error generating RSA key. Old keys restored.";
        }

        say "Error generating RSA key";
        exit 1;
    }
    
    File::Find::find(sub {
        unlink $_;
    }, "/etc/back/keys/old");
    
    File::Find::find(sub {
        if ($_ =~ /.+key.old/) {
            File::Copy::copy("/etc/back/keys/" . $_, "/etc/back/keys/old/key.old");
            unlink $_;
        } elsif ($_ =~ /.+pub.old/) {
            File::Copy::copy("/etc/back/keys/" . $_, "/etc/back/keys/old/pub.old");
            unlink $_;
        } 
    }, "/etc/back/keys");

    say "RSA key generated";

    system("openssl pkeyutl -encrypt -pubin -inkey /etc/back/keys/back.pub -in /etc/back/keys/passphrase.tmp -out /etc/back/keys/passphrase");
    unlink "/etc/back/keys/passphrase.tmp";
    say "Passphrase encrypted";

}

sub encrypt {

    my $name = $_[0];
    my $pub = "";

    open(my $file, '<', "/etc/back/keys/back.pub") or die $!;
    my $public = read_file($file);
    close($file);

    system("openssl pkeyutl -decrypt -inkey /etc/back/keys/back.key -in /etc/back/keys/passphrase -out /tmp/passphrase");
    open($file, '<', "/tmp/passphrase") or die $!;
    my $passphrase = read_file($file);
    close($file);
    unlink "/tmp/passphrase";

    system("openssl enc -aes-256-cbc -pbkdf2 -in " . $name . " -out " . $name . ".enc -pass pass:" . $passphrase);
    unlink $name;

}

sub decrypt {
    my $name = $_[0];
    my $key = "";

    open(my $file, '<', "/etc/back/keys/back.key") or die $!;
    my $private = read_file($file);
    close($file);

    system("openssl pkeyutl -decrypt -inkey /etc/back/keys/back.key -in /etc/back/keys/passphrase -out /tmp/passphrase");
    open($file, '<', "/tmp/passphrase") or die $!;
    my $passphrase = read_file($file);
    close($file);
    #unlink "/tmp/passphrase";

    system("openssl enc -aes-256-cbc -pbkdf2 -d -in " . $name . " -out " . substr($name, 0, -4) . " -pass pass:" . $passphrase);
    unlink $name;

}
1;
decrypt("21-5-2023-3-47-35.zip.enc");
#generate_keys();
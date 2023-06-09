package crypt;

use strict;
use warnings;
use File::Path;
use File::Copy;
use File::Find;
use File::Slurp;
use feature qw(say);

my $config = utils::read_config();

# Cifra un file con AES-256-CBC
sub encrypt {
    my $name = shift;
    my $user = shift;
    my $dir_dim = `df -B1 /tmp | tail -1 | awk '{print \$4}'`; chomp $dir_dim;
    my $file_dim = `du -b /tmp/.$name | awk '{print \$1}'`; chomp $file_dim;
    if ($dir_dim <= $file_dim) {
        return 2;
    }
    my $dir = $config->{"BACKUP_DIR"} . ($config->{"BACKUP_DIR"} =~ /\/$/ ? "" : "/") . `id -u $user`; chomp $dir;
    if (system("openssl enc -aes-256-cbc -pbkdf2 -in /tmp/." . $name . " -out " . $dir . "/" . $name . ".enc -pass pass:" . get_passphrase()) != 0) {
        return 1;
    }
    unlink $name;
    return 0;
}

# Decifra un file con AES-256-CBC
sub decrypt {
    my $name = shift;
    my $user = shift;
    my $dir = $config->{"BACKUP_DIR"} . ($config->{"BACKUP_DIR"} =~ /\/$/ ? "" : "/") . `id -u $user`; chomp $dir;

    if (! -f $dir . "/" . $name) {
        return 2;
    }
    if (system("openssl enc -aes-256-cbc -pbkdf2 -d -in " . $dir . "/" . $name . " -out /tmp/." . substr($name, 0, -4) . " -pass pass:" . get_passphrase()) != 0) {
        return 1;
    }
    return 0;
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
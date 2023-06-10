package zipper;

use zip;
use crypt;
use utils;

use JSON;

my $config = utils::read_config();

# Zip a user's backup
sub zip {
    my $user = shift || "";
    my $user_dir = $config->{"BACKUP_DIR"} . ($config->{"BACKUP_DIR"} =~ /\/$/ ? "" : "/") . $user; chomp $user_dir;
    my $json_data = undef;

    # Read the user's configuration file
    $json_data = utils::read_user_json($user);

    # Make the backup
    $backup = zip::make($json_data);
    if ($backup == 1) {
        return (1, $user);
    } else {
        # Encrypt the backup
        my $err = crypt::encrypt($backup, $user);
        if ($err == 1) {
            return (2, $user);
        } elsif ($err == 2) {
            return (3, $user);
        } else {
            chomp $user;
            # Delete the oldest backup if there are more than 10
            if (`ls $user_dir | wc -l` + 0 > 10) {
                my @backups = `ls $user_dir`;
                sort @backups;
                `rm $user_dir/$backups[0]`;
            }
            return (0, $user);
        }
    }
}
1;

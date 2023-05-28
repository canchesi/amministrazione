package zipper;

require "./lib/zip.pm";
require "./lib/crypt.pm";
require "./lib/utils.pm";

use JSON;

sub zip {
    my $user = shift || "";
    my $json_data = undef;

    $json_data = utils::read_user_json($user);
    $backup = zip::make_backup($json_data);
    if ($backup == 1) {
        return (1, $user);
    } else {
        if (crypt::encrypt($backup, $user) == 1) {
            return (2, $user);
        } else {
            chomp $user;
            if (`ls /var/back-a-la/$user | wc -l` > 10) {
                my @backups = `ls /var/back-a-la/$user`;
                sort @backups;
                `rm /var/back-a-la/$user/$backups[0]`;
            }
            return (0, $user);
        }
    }
}
1;
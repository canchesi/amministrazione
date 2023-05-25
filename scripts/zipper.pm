package zipper;

require "./lib/zip.pm";
require "./lib/crypt.pm";
require "./lib/utils.pm";

use JSON;

sub zip {
    my $user = shift || "";
    my $json_data = undef;

    if ($user eq "") {
        return 1;
    }

    $json_data = utils::read_user_json($user);
    $backup = zip::make_backup($json_data);
    if ($backup == 1) {
        return 1;
    } else {
        if (crypt::encrypt($backup) == 1) {
            return 2;
        } else {
            return 0;
        }
    }
}
1;
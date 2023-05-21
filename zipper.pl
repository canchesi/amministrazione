require "./lib/zip.pm";
require "./lib/crypt.pm";

use JSON;

# aprire il file JSON
open(my $json_file, '<', '/etc/back/users.json') or die $!;

# leggere il contenuto del file JSON
my $json_text = join('', <$json_file>);
close($json_file);

# decodificare il contenuto JSON
my $json_data = decode_json($json_text);

# eseguire operazioni sui dati JSON
foreach my $user (keys $json_data->%*) {
    $backup = zip::make_backup($json_data->{$user}->{"directories"}->@*);
    if ($backup == undef) {
        exit 1;
    } else {
        crypt::encrypt($backup);

    }
}
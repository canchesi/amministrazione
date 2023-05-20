require "./zip.pl";

use JSON;
use Archive::Zip;

# aprire il file JSON
open(my $json_file, '<', '/etc/back/users.json') or die $!;

# leggere il contenuto del file JSON
my $json_text = join('', <$json_file>);
close($json_file);

# decodificare il contenuto JSON
my $json_data = decode_json($json_text);

# eseguire operazioni sui dati JSON
foreach my $user (keys $json_data->%*) {
    zip::make_backup($json_data->{$user}->{"directories"}->@*)
}
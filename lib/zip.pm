package zip;

use Archive::Zip;
use strict;
use warnings;
use JSON;

sub make_backup {
    my $archive = Archive::Zip->new();
    my @directories = $_[0]->@*;
    if (scalar(@directories) == 0) {
        return undef;
    } 
    foreach my $dir (@directories) {
        print $dir."\n";
        $archive->addTree($dir, $dir);
    }
    my @date = getDate();
    my $name = "";
    foreach my $elem (@date[0..4]) {
        $name .= $elem . "-"
    }
    $name .= $date[5];
    if ($archive->writeToFileNamed("/tmp/.$name.zip") == 0) {
        return $name.".zip";
    } else {
        return 1;
    }
}

sub getDate {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    return ($mday, $mon+1, $year+1900, $hour, $min, $sec);
}
1;
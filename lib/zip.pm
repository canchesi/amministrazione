package zip;

use Archive::Zip;
use strict;
use warnings;
use JSON;
use File::Finder;

sub make {
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

sub extract {
    my $name = shift;
    my $user = shift;
    my $zip = Archive::Zip->new();
    if ($zip->read("/tmp/." . $name) != 0) {
        return 1;
    }
    foreach my $member ($zip->members()) {
        $zip->extractTree($member->fileName(), "/" . $member->fileName());
    	chown $user, $user, "/" .$member->fileName();
    }
    return 0;

}

sub getDate {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    return ($year+1900, $mon+1, $mday, $hour, $min, $sec);
}
1;

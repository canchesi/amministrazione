package zip;

use Archive::Zip;
use strict;
use warnings;
use JSON;
use File::Finder;

# Make a zip archive of the given directories
sub make {
    my $archive = Archive::Zip->new();
    my @directories = $_[0]->@*;
    if (scalar(@directories) == 0) {
        return undef;
    } 

    # Add the directories to the archive
    foreach my $dir (@directories) {
        $archive->addTree($dir, $dir);
    }
    
    # Create the name of the archive using the current date
    my @date = getDate();
    my $name = "";
    foreach my $elem (@date[0..4]) {
        $name .= $elem . "-"
    }
    $name .= $date[5];
    
    # Write the archive to a file
    if ($archive->writeToFileNamed("/tmp/.$name.zip") == 0) {
        return $name.".zip";
    } else {
        return 1;
    }
}

# Extract the given archive
sub extract {
    my $name = shift;
    my $user = shift;
    my $zip = Archive::Zip->new();

    # Extract the archive
    if ($zip->read("/tmp/." . $name) != 0) {
        return 1;
    }
    
    # For each member of the archive, changes its owner to the backup's user
    foreach my $member ($zip->members()) {
        $zip->extractTree($member->fileName(), "/" . $member->fileName());
    	chown $user, $user, "/" .$member->fileName();
    }
    return 0;

}

# Get the current date and format it
sub getDate {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    return ($year+1900, $mon+1, $mday, $hour, $min, $sec);
}
1;

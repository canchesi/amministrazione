use lib "/home/claudio/amministrazione/lib";
use lib "/home/claudio/amministrazione/scripts";
use lib "/home/claudio/amministrazione/commands";
use 

use threads;
use IO::Socket::UNIX;

my %functionalities = ();

$functionalities{"interface"} = threads->create(\&interface::interface);


$functionalities{"interface"}->join();
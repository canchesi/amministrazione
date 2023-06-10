use lib "./lib";
use lib "./scripts";
use lib "./commands";
use interface;

use threads;
use IO::Socket::UNIX;

my %functionalities = ();

$functionalities{"interface"} = threads->create(\&interface::interface);


$functionalities{"interface"}->join();
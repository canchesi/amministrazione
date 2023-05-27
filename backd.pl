require './scripts/interface.pm';

use threads;
use IO::Socket::UNIX;

my %functionalities = ();

$functionalities{"interface"} = threads->create(\&interface::interface);


$functionalities{"interface"}->join();
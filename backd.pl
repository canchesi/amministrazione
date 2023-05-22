require './scripts/interface.pm';

use Thread;
use IO::Socket::UNIX;

my %functionalities = ();

$functionalities{"interface"} = Thread->new(\&interface::interface);


$functionalities{"interface"}->join();
use lib "./lib";
use lib "./scripts";
use lib "./commands";
use interface;

use threads;
use IO::Socket::UNIX;

# Starts the daemon
my $interface = threads->create(\&interface::interface);
$interface->join();
package conn;

use strict;
use warnings;
use IO::Socket::UNIX;

sub create_socket {

    # Remove the socket if it already exists
    if (-e "/run/back.sock") {
        unlink "/run/back.sock";
    }

    # Create the socket
    my $socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM(),
        Local => "/run/back.sock",
        Listen => 1
    ) or die $!;

    # Set the socket permissions
    my $back = `grep '^back:' /etc/group | cut -d: -f3`;
    chown 0, $back, "/run/back.sock";
    chmod 0660, "/run/back.sock";
    return $socket;
}

# Accepts a connection from the socket
sub accept_connection {
    my $socket = shift;
    my $connection = $socket->accept();
    return $connection;
}

# Closes the socket
sub close_socket {
    my $socket = shift;
    $socket->close();
}
1;
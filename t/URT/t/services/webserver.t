#!/usr/bin/env perl

use Test::More;
use File::Basename;
use lib File::Basename::dirname(__FILE__)."/../../../../lib";
use lib File::Basename::dirname(__FILE__)."/../../..";
use UR;
use strict;
use warnings;

use IO::Socket;

plan tests => 14;

# Test out the lazy host and port methods
{
    my $srv = UR::Service::WebServer->create();
    ok($srv, 'Created WebServer service');
    $srv->dump_status_messages(0);
    $srv->queue_status_messages(1);

    is($srv->port(12345), 12345, 'Can change port before socket is created');
    is($srv->port(undef), undef, 'Change port back to undef');
    is($srv->host('abc'), 'abc', 'Can change host before socket is created');
    is($srv->host(undef), undef, 'Change host back to undef');

    my $port = $srv->port;
    ok($port, 'Forced port to be filled in');
    my $host = $srv->host;
    my $server = $srv->server;
    is($port, $server->listen_sock->sockport, "autogenerated port matches server's sockport");
    is($host, $server->listen_sock->sockhost, "autogenerated port matches server's sockhost");

    ok( !eval { $srv->port($port + 1) }, 'Setting port after socket creation fails');
    like($@, qr(Cannot change port), 'Exception looks correct');
    ok( !eval { $srv->host($host .'aa') }, 'Setting host after socket creation fails');
    like($@, qr(Cannot change host), 'Exception looks correct');
}

# test out making a socket with a random port and connecting to it
{
    my $srv = UR::Service::WebServer->create();
    ok($srv, 'Created WebServer service');

    $srv->dump_status_messages(0);
    $srv->queue_status_messages(1);
    my $server = $srv->server();
    isa_ok($server, 'UR::Service::WebServer::Server');

    ok($server->setup_listener, 'setup_listener');
    my $sock = $server->listen_sock;
    my $port = $sock->sockport;
    ok($port, "server is listening on random port: $port");
    my $host = $sock->sockhost;
    is($host, '127.0.0.1', 'Default listening on localhost');

    # try connecting
    my $conn = IO::Socket::INET->new(PeerAddr => $host, PeerPort => $port, Proto => 'tcp');
    ok($conn, 'Connected');
    $conn->close();

    ok($srv->delete(), 'Delete WebServer');
    # try connecting again
    $conn = IO::Socket::INET->new(PeerAddr => $host, PeerPort => $port, Proto => 'tcp');
    ok(!$conn, "Connection to deleted WebServer failed: $!");
}


# Make another and specify the listen port
{
    my $tryport = pick_random_port();
    my $srv = UR::Service::WebServer->create(port => $tryport);
    ok($srv, 'Create WebServer service specifying port');
    $srv->dump_status_messages(0);
    $srv->queue_status_messages(1);

    ok($srv->server->setup_listener, 'setup_listener');
    my $sock = $srv->server->listen_sock;
    my $port = $sock->sockport;
    is($port, $tryport, 'Listen port is correct');

    # try connecting
    my $conn = IO::Socket::INET->new(PeerAddr => 'localhost', PeerPort => $tryport, Proto => 'tcp');
    ok($conn, 'Connected');
    $conn->close();

    $srv->delete();
}

# Test the idle timeout
{
    my $srv = UR::Service::WebServer->create(idle_timeout => 1);
    ok($srv, 'Created WebServer service');
    $srv->dump_status_messages(0);
    $srv->queue_status_messages(1);

    # NOTE - This will hang if the test fails :(
    $srv->run();
    ok(1, 'timeout');

    $srv->delete();
}

sub pick_random_port {
    # Have the system make socket and pick the port for us
    my $trysock = IO::Socket::INET->new(Listen => 1, Proto => 'tcp', LocalAddr => 'localhost');
    my $tryport = $trysock->sockport;
    # Now close this socket, and tell the WebServer to use the same socket
    # There's a small chance of a race condition here if another process
    # re-uses the same port number, but the chance is _really_ small, since the
    # port is in TIME_WAIT.  The underlying socket open in the webserver code
    # uses SO_REUSEADDR to re-open the port.
    $trysock->close();
    return $tryport;
}


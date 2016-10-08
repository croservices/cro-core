use Crow::TCP;
use Test;

# Type relationships.
ok Crow::TCP::Listener ~~ Crow::Listener, 'TCP listener is a listener';
ok Crow::TCP::Listener.produces ~~ Crow::TCP::Connection, 'TCP listener produces connections';
ok Crow::TCP::Connection ~~ Crow::Connection, 'TCP connection is a connection';
ok Crow::TCP::Connection.sends ~~ Crow::TCP::Message, 'TCP connection sends TCP messages';
ok Crow::TCP::Connection.receives ~~ Crow::TCP::Message, 'TCP connection receives TCP messages';

# Crow::TCP::Listener
{
    my $lis = Crow::TCP::Listener.new(port => 31313);
    is $lis.port, 31313, 'Listener has correct port';
    dies-ok { await IO::Socket::Async.connect('127.0.0.1', 31313) },
        'Not listening simply by creating the object';

    my $incoming = $lis.incoming;
    ok $incoming ~~ Supply, 'incoming returns a Supply';
    dies-ok { await IO::Socket::Async.connect('127.0.0.1', 31313) },
        'Still not listening as Supply not yet tapped';

    my $server-conns = Channel.new;
    my $tap = $incoming.tap({ $server-conns.send($_) });
    my $client-conn-a;
    lives-ok { $client-conn-a = await IO::Socket::Async.connect('127.0.0.1', 31313) },
        'Listening for connections once the Supply is tapped';
    ok $server-conns.receive ~~ Crow::TCP::Connection,
        'Listener emitted a TCP connection';
    nok $server-conns.poll, 'Only that one connection emitted';
    $client-conn-a.close;

    my $client-conn-b = await IO::Socket::Async.connect('127.0.0.1', 31313);
    ok $server-conns.receive ~~ Crow::TCP::Connection,
        'Listener emitted second connection';
    nok $server-conns.poll, 'Only that one connection emitted';
    $client-conn-b.close;

    $tap.close;
    dies-ok { await IO::Socket::Async.connect('127.0.0.1', 31313) },
        'Not listening after Supply tap closed';
}

done-testing;

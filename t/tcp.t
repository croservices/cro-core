use Crow::TCP;
use Test;

constant TEST_PORT = 31313;

# Type relationships.
ok Crow::TCP::Listener ~~ Crow::Listener, 'TCP listener is a listener';
ok Crow::TCP::Listener.produces ~~ Crow::TCP::Connection, 'TCP listener produces connections';
ok Crow::TCP::Connection ~~ Crow::Connection, 'TCP connection is a connection';
ok Crow::TCP::Connection.sends ~~ Crow::TCP::Message, 'TCP connection sends TCP messages';
ok Crow::TCP::Connection.receives ~~ Crow::TCP::Message, 'TCP connection receives TCP messages';
ok Crow::TCP::Message ~~ Crow::Message, 'TCP message is a message';

# Crow::TCP::Listener
{
    my $lis = Crow::TCP::Listener.new(port => TEST_PORT);
    is $lis.port, TEST_PORT, 'Listener has correct port';
    dies-ok { await IO::Socket::Async.connect('127.0.0.1', TEST_PORT) },
        'Not listening simply by creating the object';

    my $incoming = $lis.incoming;
    ok $incoming ~~ Supply, 'incoming returns a Supply';
    dies-ok { await IO::Socket::Async.connect('127.0.0.1', TEST_PORT) },
        'Still not listening as Supply not yet tapped';

    my $server-conns = Channel.new;
    my $tap = $incoming.tap({ $server-conns.send($_) });
    my $client-conn-a;
    lives-ok { $client-conn-a = await IO::Socket::Async.connect('127.0.0.1', TEST_PORT) },
        'Listening for connections once the Supply is tapped';
    ok $server-conns.receive ~~ Crow::TCP::Connection,
        'Listener emitted a TCP connection';
    nok $server-conns.poll, 'Only that one connection emitted';
    $client-conn-a.close;

    my $client-conn-b = await IO::Socket::Async.connect('127.0.0.1', TEST_PORT);
    ok $server-conns.receive ~~ Crow::TCP::Connection,
        'Listener emitted second connection';
    nok $server-conns.poll, 'Only that one connection emitted';
    $client-conn-b.close;

    $tap.close;
    dies-ok { await IO::Socket::Async.connect('127.0.0.1', TEST_PORT) },
        'Not listening after Supply tap closed';
}

# Crow::TCP::Connection and Crow::TCP::Message
{
    my $lis = Crow::TCP::Listener.new(port => TEST_PORT);
    my $server-conns = Channel.new;
    my $tap = $lis.incoming.tap({ $server-conns.send($_) });
    my $client-conn = await IO::Socket::Async.connect('127.0.0.1', TEST_PORT);
    my $client-received = Channel.new;
    $client-conn.Supply(:bin).tap({ $client-received.send($_) });
    my $server-conn = $server-conns.receive;

    my $rec-supply = $server-conn.incoming;
    ok $rec-supply ~~ Supply, 'Connection incoming method returns a Supply';

    my $received = Channel.new;
    $rec-supply.tap({ $received.send($_) });

    $client-conn.write('First packet'.encode('utf-8'));
    my $first-message = $received.receive;
    ok $first-message ~~ Crow::TCP::Message,
        'Received message is a Crow::TCP::Message';
    ok $first-message.data ~~ Blob,
        'Message data is in a Blob';
    is $first-message.data.decode('utf-8'), 'First packet',
        'Message data has correct value';

    $client-conn.write(Blob.new(0xFE, 0xED, 0xBE, 0xEF));
    my $second-message = $received.receive;
    ok $second-message ~~ Crow::TCP::Message,
        'Second received message is a Crow::TCP::Message';
    ok $second-message.data ~~ Blob,
        'Second message data is in a Blob';
    is $second-message.data.list, (0xFE, 0xED, 0xBE, 0xEF),
        'Second message data has correct value';

    $server-conn.send('First reply'.encode('utf-8'));
    is $client-received.receive.decode('utf-8'), 'First reply',
        'Blob reply sent successfully';

    $server-conn.send(Crow::TCP::Message.new(data => 'Second reply'.encode('utf-8')));
    is $client-received.receive.decode('utf-8'), 'Second reply',
        'TCP::Message reply sent successfully';
}

# Crow::TCP::Client

# Crow::TCP::Server

done-testing;

use Crow;
use Crow::TCP;
use Test;

constant TEST_PORT = 31313;

# Type relationships.
ok Crow::TCP::Listener ~~ Crow::Source, 'TCP listener is a source';
ok Crow::TCP::Listener.produces ~~ Crow::TCP::Connection, 'TCP listener produces connections';
ok Crow::TCP::Connection ~~ Crow::Connection, 'TCP connection is a connection';
ok Crow::TCP::Connection ~~ Crow::Replyable, 'TCP connection is replyable';
ok Crow::TCP::Connection.produces ~~ Crow::TCP::Message, 'TCP connection produces TCP messages';
ok Crow::TCP::Message ~~ Crow::Message, 'TCP message is a message';

# Crow::TCP::Listener
{
    my $lis = Crow::TCP::Listener.new(port => TEST_PORT);
    is $lis.port, TEST_PORT, 'Listener has correct port';
    dies-ok { await IO::Socket::Async.connect('localhost', TEST_PORT) },
        'Not listening simply by creating the object';

    my $incoming = $lis.incoming;
    ok $incoming ~~ Supply, 'incoming returns a Supply';
    dies-ok { await IO::Socket::Async.connect('localhost', TEST_PORT) },
        'Still not listening as Supply not yet tapped';

    my $server-conns = Channel.new;
    my $tap = $incoming.tap({ $server-conns.send($_) });
    my $client-conn-a;
    lives-ok { $client-conn-a = await IO::Socket::Async.connect('localhost', TEST_PORT) },
        'Listening for connections once the Supply is tapped';
    ok $server-conns.receive ~~ Crow::TCP::Connection,
        'Listener emitted a TCP connection';
    nok $server-conns.poll, 'Only that one connection emitted';
    $client-conn-a.close;

    my $client-conn-b = await IO::Socket::Async.connect('localhost', TEST_PORT);
    ok $server-conns.receive ~~ Crow::TCP::Connection,
        'Listener emitted second connection';
    nok $server-conns.poll, 'Only that one connection emitted';
    $client-conn-b.close;

    $tap.close;
    dies-ok { await IO::Socket::Async.connect('localhost', TEST_PORT) },
        'Not listening after Supply tap closed';
}

# Crow::TCP::Connection and Crow::TCP::Message
{
    my $lis = Crow::TCP::Listener.new(port => TEST_PORT);
    my $server-conns = Channel.new;
    my $tap = $lis.incoming.tap({ $server-conns.send($_) });
    my $client-conn = await IO::Socket::Async.connect('localhost', TEST_PORT);
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

    my $replier = $server-conn.replier;
    ok $replier ~~ Crow::Sink, 'The TCP connection replier is a Crow::Sink';

    my $fake-replies = Supplier.new;
    my $sinker = $replier.sinker($fake-replies.Supply);
    ok $sinker ~~ Supply, 'Reply sinker returns a Supply';
    lives-ok { $sinker.tap }, 'Can tap that Supply';

    $fake-replies.emit(Crow::TCP::Message.new(data => 'First reply'.encode('utf-8')));
    is $client-received.receive.decode('utf-8'), 'First reply',
        'First TCP::Message reply sent successfully';

    $fake-replies.emit(Crow::TCP::Message.new(data => 'Second reply'.encode('utf-8')));
    is $client-received.receive.decode('utf-8'), 'Second reply',
        'Second TCP::Message reply sent successfully';

    $client-conn.close;
    $tap.close;
}

{
    my class UppercaseTransform does Crow::Transform {
        method consumes() { Crow::TCP::Message }
        method produces() { Crow::TCP::Message }
        method transformer($incoming) {
            supply {
                whenever $incoming -> $message {
                    $message.data = $message.data.decode('latin-1').uc.encode('latin-1');
                    emit $message;
                }
            }
        }
    }

    my $listener = Crow::TCP::Listener.new(port => TEST_PORT);
    my $loud-service = Crow.compose($listener, UppercaseTransform);
    ok $loud-service ~~ Crow::Service,
        'TCP::Listener and a transform compose to make a service';
    lives-ok { $loud-service.start }, 'Can start the service';

    my $client-conn-a = await IO::Socket::Async.connect('localhost', TEST_PORT);
    my $client-received-a = Channel.new;
    $client-conn-a.Supply(:bin).tap({ $client-received-a.send($_) });
    $client-conn-a.print("Can you hear me?");
    is $client-received-a.receive.decode('latin-1'), "CAN YOU HEAR ME?",
        'Service processes messages (first connection)';

    my $client-conn-b = await IO::Socket::Async.connect('localhost', TEST_PORT);
    my $client-received-b = Channel.new;
    $client-conn-b.Supply(:bin).tap({ $client-received-b.send($_) });
    $client-conn-b.print("I'm over here!");
    is $client-received-b.receive.decode('latin-1'), "I'M OVER HERE!",
        'Service processes messages (second concurrent connection)';

    $client-conn-a.print("No, not there...");
    is $client-received-a.receive.decode('latin-1'), "NO, NOT THERE...",
        'Further messages on first connection processed';
    $client-conn-a.close;

    $client-conn-b.print("Bah, you suck at this");
    is $client-received-b.receive.decode('latin-1'), "BAH, YOU SUCK AT THIS",
        'Second connection fine after first closed';
    $client-conn-b.close;

    lives-ok { $loud-service.stop }, 'Can stop the service';
    dies-ok { await IO::Socket::Async.connect('localhost', TEST_PORT) },
        'Cannot connect to service after it has been stopped';
}

done-testing;

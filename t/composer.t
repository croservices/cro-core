use Crow;
use Crow::Connector;
use Crow::Message;
use Crow::Replyable;
use Crow::Sink;
use Crow::Source;
use Crow::Transform;
use Test;

my class TestMessage does Crow::Message {
    has Str $.body;
}

throws-like { Crow.compose() }, X::Crow::Compose::Empty;
throws-like { Crow.compose(Any) }, X::Crow::Compose::InvalidType;
throws-like { Crow.compose(TestMessage) }, X::Crow::Compose::InvalidType;

my class TestMessageSource does Crow::Source {
    method produces() { TestMessage }
    method incoming() returns Supply:D {
        supply {
            emit TestMessage.new(body => 'korbačky');
            emit TestMessage.new(body => 'pivo');
        }
    }
}

{
    my $comp = Crow.compose(TestMessageSource);
    ok $comp ~~ Crow::Source, 'Composing just a source produces a Crow::Source';
    ok $comp ~~ Crow::CompositeSource, 'More specifically, a Crow::CompositeSource';
    is $comp.produces, TestMessage, 'Composite source has correct produces';
    my @incoming = $comp.incoming.list;
    is @incoming.elems, 2, 'Got two messages from the composite source';
    for @incoming {
        ok .isa(TestMessage), 'Message of correct type';
    }
    is @incoming>>.body, ('korbačky', 'pivo'), 'Messages have correct bodies';
}

my class TestBinaryMessage does Crow::Message {
    has Blob $.body;
}
my class TestTransform does Crow::Transform {
    method consumes() { TestMessage }
    method produces() { TestBinaryMessage }
    method transformer(Supply:D $in) returns Supply:D {
        supply {
            whenever $in -> $message {
                emit TestBinaryMessage.new(body => $message.body.encode('utf-8'));
            }
        }
    }
}

{
    my $comp = Crow.compose(TestMessageSource, TestTransform);
    ok $comp ~~ Crow::Source, 'Composing source and transform produces a Crow::Source';
    ok $comp ~~ Crow::CompositeSource, 'More specifically, a Crow::CompositeSource';
    is $comp.produces, TestBinaryMessage, 'Composite source has correct produces';
    my @incoming = $comp.incoming.list;
    is @incoming.elems, 2, 'Got two messages from the composite source';
    for @incoming {
        ok .isa(TestBinaryMessage), 'Message of correct type';
    }
    is-deeply @incoming[0].body, 'korbačky'.encode('utf-8'),
        'Correct first transformed message';
    is-deeply @incoming[1].body, 'pivo'.encode('utf-8'),
        'Correct second transformed message';
}

throws-like { Crow.compose(TestTransform, TestMessageSource) },
    X::Crow::Compose::SourceMustBeFirst;
throws-like { Crow.compose(TestMessageSource, TestMessageSource) },
    X::Crow::Compose::SourceMustBeFirst;

{
    my $comp = Crow.compose(TestTransform);
    ok $comp ~~ Crow::Transform, 'Composing just a transform produces a Crow::Transform';
    ok $comp ~~ Crow::CompositeTransform, 'More specifically, a Crow::CompositeTransform';
    is $comp.consumes, TestMessage, 'Composite transform has correct consumes';
    is $comp.produces, TestBinaryMessage, 'Composite transform has correct produces';
    my @fake-messages = <porek mrkev>.map: { TestMessage.new(body => $_) };
    my $tran = $comp.transformer(Supply.from-list(@fake-messages));
    isa-ok $tran, Supply, 'Composite transform returns a Supply';
    my @transformed = $tran.list;
    is @transformed.elems, 2, 'Got two messages from the composite transform';
    for @transformed {
        ok .isa(TestBinaryMessage), 'Message of correct type';
    }
    is-deeply @transformed[0].body, 'porek'.encode('utf-8'),
        'Correct first transformed message';
    is-deeply @transformed[1].body, 'mrkev'.encode('utf-8'),
        'Correct second transformed message';
}

my class TestIntMessage does Crow::Message {
    has Int $.value;
}
my class AnotherTestTransform does Crow::Transform {
    method consumes() { TestBinaryMessage }
    method produces() { TestIntMessage }
    method transformer(Supply:D $in) returns Supply:D {
        supply {
            whenever $in -> $message {
                emit TestIntMessage.new(value => $message.body.elems);
            }
        }
    }
}

{
    my $comp = Crow.compose(TestTransform, AnotherTestTransform);
    ok $comp ~~ Crow::Transform, 'Composing two transforms produces a Crow::Transform';
    ok $comp ~~ Crow::CompositeTransform, 'More specifically, a Crow::CompositeTransform';
    is $comp.consumes, TestMessage, 'Composite transform has correct consumes';
    is $comp.produces, TestIntMessage, 'Composite transform has correct produces';
    my @fake-messages = <brambor skořice>.map: { TestMessage.new(body => $_) };
    my $tran = $comp.transformer(Supply.from-list(@fake-messages));
    isa-ok $tran, Supply, 'Composite transform returns a Supply';
    my @transformed = $tran.list;
    is @transformed.elems, 2, 'Got two messages from the composite transform';
    for @transformed {
        ok .isa(TestIntMessage), 'Message of correct type';
    }
    is @transformed>>.value, (7, 8), 'Correctly applied both transforms to messages';
}

my class TestSink does Crow::Sink {
    has Int $.sum = 0;
    method consumes() { TestIntMessage }
    method sinker(Supply:D $in) returns Supply:D {
        supply {
            whenever $in -> $message {
                $!sum += $message.value;
            }
        }
    }
}

{
    my $sink = TestSink.new;
    my $comp = Crow.compose($sink);
    ok $comp ~~ Crow::Sink, 'Composing just a sink produces a Crow::Sink';
    ok $comp ~~ Crow::CompositeSink, 'More specifically, a Crow::CompositeSink';
    is $comp.consumes, TestIntMessage, 'Composite sink has correct consumes';
    my @fake-messages = (5, 37).map: { TestIntMessage.new(value => $_) };
    my $sink-supply = $comp.sinker(Supply.from-list(@fake-messages));
    isa-ok $sink-supply, Supply, 'Composite sink returns a Supply';
    is $sink-supply.list.elems, 0, 'Sink does not produce any messages';
    is $sink.sum, 42, 'Composite sink processed messages';
}

{
    my $sink = TestSink.new;
    my $comp = Crow.compose(TestTransform, AnotherTestTransform, $sink);
    ok $comp ~~ Crow::Sink, 'Composing transforms and sink produces a Crow::Sink';
    ok $comp ~~ Crow::CompositeSink, 'More specifically, a Crow::CompositeSink';
    is $comp.consumes, TestMessage, 'Composite sink has correct consumes';
    my @fake-messages = <máta hovězí>.map: { TestMessage.new(body => $_) };
    my $sink-supply = $comp.sinker(Supply.from-list(@fake-messages));
    isa-ok $sink-supply, Supply, 'Composite sink returns a Supply';
    is $sink-supply.list.elems, 0, 'Sink does not produce any messages';
    is $sink.sum, 13, 'Composite sink processed messages';
}

throws-like { Crow.compose(AnotherTestTransform, TestSink, TestTransform) },
    X::Crow::Compose::SinkMustBeLast;
throws-like { Crow.compose(TestSink, TestTransform) },
    X::Crow::Compose::SinkMustBeLast;
throws-like { Crow.compose(TestSink, TestMessageSource) },
    X::Crow::Compose::SinkMustBeLast;

{
    my $sink = TestSink.new;
    my $comp = Crow.compose(TestMessageSource, TestTransform, AnotherTestTransform, $sink);
    ok $comp ~~ Crow::Service, 'Composing source/transform/sink gives a Crow::Service';
    $comp.start();
    is $sink.sum, 13, 'Starting service processes all messages';
}

throws-like { Crow.compose(TestMessageSource, TestSink) },
    X::Crow::Compose::Mismatch,
    producer => TestMessageSource,
    consumer => TestSink;
throws-like { Crow.compose(TestMessageSource, AnotherTestTransform) },
    X::Crow::Compose::Mismatch,
    producer => TestMessageSource,
    consumer => AnotherTestTransform;
throws-like { Crow.compose(TestMessageSource, TestTransform, TestSink) },
    X::Crow::Compose::Mismatch,
    producer => TestTransform,
    consumer => TestSink;

my class NaughtySource does Crow::Source {
    method produces() { Int }
    method incoming() { supply { } }
}
my class NaughtyTransform1 does Crow::Transform {
    method consumes() { Int }
    method produces() { TestMessage }
    method transformer($pipeline) { supply { } }
}
my class NaughtyTransform2 does Crow::Transform {
    method consumes() { TestMessage }
    method produces() { Int }
    method transformer($pipeline) { supply { } }
}
my class NaughtySink does Crow::Sink {
    method consumes() { Int }
    method sinker($pipeline) { supply { } }
}
throws-like { Crow.compose(NaughtySource) },
    X::Crow::Compose::BadProducer,
    producer => NaughtySource;
throws-like { Crow.compose(NaughtyTransform1) },
    X::Crow::Compose::BadConsumer,
    consumer => NaughtyTransform1;
throws-like { Crow.compose(NaughtyTransform2) },
    X::Crow::Compose::BadProducer,
    producer => NaughtyTransform2;
throws-like { Crow.compose(NaughtySink) },
    X::Crow::Compose::BadConsumer,
    consumer => NaughtySink;

class TestReplyableSourceWithSink does Crow::Source does Crow::Replyable {
    has $.sinker = TestSink.new;
    method produces() { TestMessage }
    method incoming() returns Supply:D {
        supply {
            emit TestMessage.new(body => 'vánoce');
            emit TestMessage.new(body => 'stromek');
        }
    }
    method replier() returns Crow::Replier {
        $!sinker
    }
}

{
    my $test-reply-source = TestReplyableSourceWithSink.new();
    my $comp = Crow.compose($test-reply-source, TestTransform, AnotherTestTransform);
    ok $comp ~~ Crow::Service,
        'Composing source+transforms with sink from replyable source gives a Crow::Service';
    $comp.start();
    is $test-reply-source.sinker.sum, 14,
        'Starting service uses sink to consume messages';
}

{
    my $reply-source = TestReplyableSourceWithSink.new;
    my $sink = TestSink.new;
    throws-like {
            Crow.compose($reply-source, TestTransform, AnotherTestTransform, $sink)
        },
        X::Crow::Compose::TooManySinks,
        replyable => TestReplyableSourceWithSink,
        'Cannot have sink from replyable as well as sink already in the pipeline';
    throws-like {
            Crow.compose($reply-source, TestTransform)
        },
        X::Crow::Compose::Mismatch,
        producer => TestTransform,
        consumer => $reply-source.replier,
        'Sink from replyable must type match the last producer before it';
}

class TestReplyableSourceWithTransform1 does Crow::Source does Crow::Replyable {
    method produces() { TestMessage }
    method incoming() returns Supply:D {
        supply {
            emit TestMessage.new(body => 'vánoce');
            emit TestMessage.new(body => 'stromek');
        }
    }
    method replier() returns Crow::Replier {
        AnotherTestTransform
    }
}

{
    my $comp = Crow.compose(TestReplyableSourceWithTransform1, TestTransform);
    ok $comp ~~ Crow::Source,
        'Source replyable (transform to go at end) + transform produces Crow::Source';
    ok $comp ~~ Crow::CompositeSource, 'More specifically, a Crow::CompositeSource';
    is $comp.produces, TestIntMessage, 'Composite source has correct produces';
    my @incoming = $comp.incoming.list;
    is @incoming>>.value, [7, 7], 'Correct messages produced by transform';
}

class TestReplyableSourceWithTransform2 does Crow::Source does Crow::Replyable {
    method produces() { TestMessage }
    method incoming() returns Supply:D {
        supply {
            emit TestMessage.new(body => 'rajčata');
            emit TestMessage.new(body => 'česnek');
        }
    }
    method replier() returns Crow::Replier {
        TestTransform
    }
}

{
    my $comp = Crow.compose(TestReplyableSourceWithTransform2, AnotherTestTransform);
    ok $comp ~~ Crow::Source,
        'Source replyable (transform to go in middle) + transform produces Crow::Source';
    ok $comp ~~ Crow::CompositeSource, 'More specifically, a Crow::CompositeSource';
    is $comp.produces, TestIntMessage, 'Composite source has correct produces';
    my @incoming = $comp.incoming.list;
    is @incoming>>.value, [8, 7], 'Correct messages produced by transform';
}

class TestReplyableTransform does Crow::Transform does Crow::Replyable {
    method consumes() { TestMessage }
    method produces() { TestBinaryMessage }
    method transformer(Supply:D $in) returns Supply:D {
        supply {
            whenever $in -> $message {
                emit TestBinaryMessage.new(body => $message.body.encode('utf-8'));
            }
        }
    }
    method replier() returns Crow::Replier {
        AnotherTestTransform
    }
}

{
    my $test-reply-source = TestReplyableSourceWithSink.new();
    my $comp = Crow.compose($test-reply-source, TestReplyableTransform);
    ok $comp ~~ Crow::Service,
        'Source replyable (sink) + transform replyable (transform) gives Crow::Service';
    $comp.start();
    is $test-reply-source.sinker.sum, 14,
        'Service pipeline works correctly';
}

class BadReplyableTransform1 does Crow::Transform does Crow::Replyable {
    method consumes() { TestMessage }
    method produces() { TestBinaryMessage }
    method transformer(Supply:D $in) returns Supply:D {
        supply {
            whenever $in -> $message {
                emit TestBinaryMessage.new(body => $message.body.encode('utf-8'));
            }
        }
    }
    method replier() returns Crow::Replier {
        TestTransform
    }
}

{
    my $test-reply-source = TestReplyableSourceWithSink.new();
    throws-like {
            Crow.compose($test-reply-source, BadReplyableTransform1)
        },
        X::Crow::Compose::Mismatch,
        producer => BadReplyableTransform1,
        consumer => BadReplyableTransform1.replier,
        'Replyable with transform to be inserted at end with type mismatch throws';
}

class BadReplyableTransform2 does Crow::Transform does Crow::Replyable {
    method consumes() { TestMessage }
    method produces() { TestBinaryMessage }
    method transformer(Supply:D $in) returns Supply:D {
        supply {
            whenever $in -> $message {
                emit TestBinaryMessage.new(body => $message.body.encode('utf-8'));
            }
        }
    }
    method replier() returns Crow::Replier {
        TestSink.new
    }
}

{
    my $test-reply-source = TestReplyableSourceWithSink.new();
    throws-like {
            Crow.compose($test-reply-source, BadReplyableTransform2, AnotherTestTransform)
        },
        X::Crow::Compose::TooManySinks,
        replyable => $test-reply-source,
        'Cannot have two replyables that provide sinks';
}

class BadReplyableSource1 does Crow::Source does Crow::Replyable {
    method produces() { TestMessage }
    method incoming() returns Supply:D {
        supply { }
    }
    method replier() {
        TestMessageSource
    }
}
class BadReplyableSource2 does Crow::Source does Crow::Replyable {
    method produces() { TestMessage }
    method incoming() returns Supply:D {
        supply { }
    }
    method replier() {
        'lol not even a Crow::Thing'
    }
}
class BadReplyableTransform3 does Crow::Transform does Crow::Replyable {
    method consumes() { TestMessage }
    method produces() { TestBinaryMessage }
    method transformer(Supply:D $in) returns Supply:D {
        supply { }
    }
    method replier() {
        TestMessageSource
    }
}
class BadReplyableTransform4 does Crow::Transform does Crow::Replyable {
    method consumes() { TestMessage }
    method produces() { TestBinaryMessage }
    method transformer(Supply:D $in) returns Supply:D {
        supply { }
    }
    method replier() {
        'lol not even a Crow::Thing'
    }
}

{
    throws-like {
            Crow.compose(BadReplyableSource1, TestTransform)
        },
        X::Crow::Compose::BadReplier,
        replyable => BadReplyableSource1,
        'A replyable source cannot return a Crow::Source from replier';
    throws-like {
            Crow.compose(BadReplyableSource2, TestTransform)
        },
        X::Crow::Compose::BadReplier,
        replyable => BadReplyableSource2,
        'A replyable source must return a Crow::Transform or a Crow::Sink';
    throws-like {
            Crow.compose(BadReplyableTransform3, AnotherTestTransform)
        },
        X::Crow::Compose::BadReplier,
        replyable => BadReplyableTransform3,
        'A replyable transform cannot return a Crow::Source from replier';
    throws-like {
            Crow.compose(BadReplyableTransform4, AnotherTestTransform)
        },
        X::Crow::Compose::BadReplier,
        replyable => BadReplyableTransform4,
        'A replyable transform must return a Crow::Transform or a Crow::Sink';
}

my class TestConnection does Crow::Connection does Crow::Replyable {
    has Supplier $.send .= new;
    has Supplier $!replier .= new;
    method receive() { $!replier.Supply }

    method produces() { TestMessage }
    method incoming() { $!send.Supply }

    method replier() {
        class :: does Crow::Sink {
            has $.replier;
            method consumes() { TestMessage }
            method sinker($input) {
                supply {
                    whenever $input {
                        $!replier.emit(.body);
                        LAST $!replier.emit('(closed)');
                    }
                }
            }
        }.new(:$!replier)
    }
}
my class TestConnectionSource does Crow::Source {
    has Supplier $.connection-injection .= new;
    method produces() { TestConnection }
    method incoming() {
        $!connection-injection.Supply
    }
}
my class TestUppercaseTransform does Crow::Transform {
    method consumes() { TestMessage }
    method produces() { TestMessage }
    method transformer($input) {
        supply {
            whenever $input {
                emit TestMessage.new(body => .body.uc)
            }
        }
    }
}

{
    my $conn-source = TestConnectionSource.new();
    my $service = Crow.compose($conn-source, TestUppercaseTransform);
    ok $service ~~ Crow::Service,
        'Connection source with replyable connection and transform makes a Crow::Service';
    lives-ok { $service.start },
        'Could start service involving connection manager';

    my $conn-a = TestConnection.new;
    $conn-source.connection-injection.emit($conn-a);
    my $response-channel-a = $conn-a.receive.Channel;
    $conn-a.send.emit(TestMessage.new(body => 'bbq'));
    is $response-channel-a.receive, 'BBQ', 'First connection first message processed';

    my $conn-b = TestConnection.new;
    $conn-source.connection-injection.emit($conn-b);
    my $response-channel-b = $conn-b.receive.Channel;
    $conn-b.send.emit(TestMessage.new(body => 'wok'));
    is $response-channel-b.receive, 'WOK',
        'Second connection first message processed (while first connection open)';

    $conn-a.send.emit(TestMessage.new(body => 'beef'));
    is $response-channel-a.receive, 'BEEF', 'First connection second message processed';
    $conn-a.send.done;
    is $response-channel-a.receive, '(closed)',
        'First connection close communicated to sink';

    $conn-b.send.emit(TestMessage.new(body => 'pork'));
    is $response-channel-b.receive, 'PORK',
        'Second connection second message processed (after first connection closed)';
    $conn-b.send.done;
    is $response-channel-b.receive, '(closed)',
        'Second connection close communicated to sink';
}

{
    my $conn-source = TestConnectionSource.new();
    my $service = Crow.compose($conn-source);
    ok $service ~~ Crow::Service,
        'Connection source with replyable connection makes a Crow::Service';
    lives-ok { $service.start },
        'Could start identity service involving connection manager';

    my $conn = TestConnection.new;
    $conn-source.connection-injection.emit($conn);
    my $response-channel = $conn.receive.Channel;
    $conn.send.emit(TestMessage.new(body => 'maminka'));
    is $response-channel.receive, 'maminka',
        'First message echoed back';
    $conn.send.emit(TestMessage.new(body => 'miminko'));
    is $response-channel.receive, 'miminko',
        'Second message echoed back';
    $conn.send.done;
    is $response-channel.receive, '(closed)',
        'Connection close communicated to sink';
}

my class NonReplyableTestConnection does Crow::Connection {
    has Supplier $.send .= new;
    method produces() { TestMessage }
    method incoming() { $!send.Supply }
}
my class NonReplyableTestConnectionSource does Crow::Source {
    has Supplier $.connection-injection .= new;
    method produces() { NonReplyableTestConnection }
    method incoming() {
        $!connection-injection.Supply
    }
}

{
    my $conn-source = NonReplyableTestConnectionSource.new();
    throws-like { Crow.compose($conn-source, TestUppercaseTransform) },
        X::Crow::ConnectionManager::Misuse,
        'Connection manager cannot be formed if there is no sink';
}

my class CollectingTestSink does Crow::Sink {
    has $.messages = Channel.new;
    method consumes() { TestMessage }
    method sinker(Supply:D $in) returns Supply:D {
        supply {
            whenever $in -> $message {
                $!messages.send($message.body);
                LAST $!messages.send('(closed)');
            }
        }
    }
}

{
    my $conn-source = NonReplyableTestConnectionSource.new();
    my $sink = CollectingTestSink.new;
    my $service = Crow.compose($conn-source, $sink);
    ok $service ~~ Crow::Service,
        'Connection source and sink make a Crow::Service';
    lives-ok { $service.start },
        'Could start service involving connection manager and explicit sink';

    my $conn = NonReplyableTestConnection.new;
    $conn-source.connection-injection.emit($conn);
    $conn.send.emit(TestMessage.new(body => 'auto'));
    is $sink.messages.receive, 'auto',
        'First message of connection received by sink';
    $conn.send.emit(TestMessage.new(body => 'kolo'));
    is $sink.messages.receive, 'kolo',
        'Second message of connection received by sink';
    $conn.send.done;
    is $sink.messages.receive, '(closed)',
        'Connection close communicated to sink';
}

{
    my $conn-source = NonReplyableTestConnectionSource.new();
    my $sink = CollectingTestSink.new;
    my $service = Crow.compose($conn-source, TestUppercaseTransform, $sink);
    ok $service ~~ Crow::Service,
        'Connection source, transform, and sink make a Crow::Service';
    lives-ok { $service.start },
        'Could start service involving connection manager, transform, and explicit sink';

    my $conn = NonReplyableTestConnection.new;
    $conn-source.connection-injection.emit($conn);
    $conn.send.emit(TestMessage.new(body => 'auto'));
    is $sink.messages.receive, 'AUTO',
        'First message of connection received by sink';
    $conn.send.emit(TestMessage.new(body => 'kolo'));
    is $sink.messages.receive, 'KOLO',
        'Second message of connection received by sink';
    $conn.send.done;
    is $sink.messages.receive, '(closed)',
        'Connection close communicated to sink';
}

{
    my $conn-source = TestConnectionSource.new();
    throws-like { Crow.compose($conn-source, CollectingTestSink.new) },
        X::Crow::ConnectionManager::Misuse,
        'Cannot have an explicit sink and a replyable connection';
}

my class BlockableTestMessage does Crow::Message {
    has Promise $.blocker .= new;
    has Str $.body;
}
my class BlockableTestConnection does Crow::Connection does Crow::Replyable {
    has Supplier $.send .= new;
    has Supplier $!replier .= new;
    method receive() { $!replier.Supply }

    method produces() { BlockableTestMessage }
    method incoming() { $!send.Supply }

    method replier() {
        class :: does Crow::Sink {
            has $.replier;
            method consumes() { TestMessage }
            method sinker($input) {
                supply {
                    whenever $input {
                        $!replier.emit(.body);
                        LAST $!replier.emit('(closed)');
                    }
                }
            }
        }.new(:$!replier)
    }
}
my class BlockableTestConnectionSource does Crow::Source {
    has Supplier $.connection-injection .= new;
    method produces() { BlockableTestConnection }
    method incoming() {
        $!connection-injection.Supply
    }
}
my class BlockingTransform does Crow::Transform {
    method consumes() { BlockableTestMessage }
    method produces() { BlockableTestMessage }
    method transformer($input) {
        supply {
            whenever $input {
                await .blocker;
                emit BlockableTestMessage.new(body => .body.uc)
            }
        }
    }
}

{
    my $conn-source = BlockableTestConnectionSource.new();
    my $service = Crow.compose($conn-source, BlockingTransform);
    $service.start;

    my $conn-a = BlockableTestConnection.new;
    $conn-source.connection-injection.emit($conn-a);
    my $response-channel-a = $conn-a.receive.Channel;
    my $msg-a = BlockableTestMessage.new(body => 'jalfrezi');
    start $conn-a.send.emit($msg-a); # Simulate packet deliver on thread pool

    my $conn-b = BlockableTestConnection.new;
    $conn-source.connection-injection.emit($conn-b);
    my $response-channel-b = $conn-b.receive.Channel;
    my $msg-b = BlockableTestMessage.new(body => 'madras');
    start $conn-b.send.emit($msg-b); # Simulate packet deliver on thread pool

    nok $response-channel-a.poll, 'Reply on first connection not yet (sanity)';
    nok $response-channel-b.poll, 'Reply on second connection not yet (sanity)';

    $msg-b.blocker.keep(True);
    is $response-channel-b.receive, 'MADRAS',
        'After unblock of second connection, message received, even if first still blocked';
    $conn-b.send.done;
    is $response-channel-b.receive, '(closed)',
        'Can close second connection even if first still blocking';

    $msg-a.blocker.keep(True);
    is $response-channel-a.receive, 'JALFREZI',
        'After unblock of first connection, message received';
    $conn-a.send.done;
    is $response-channel-a.receive, '(closed)',
        'Can close first connection too';
}

my class TestConnector does Crow::Connector {
    class Transform does Crow::Transform {
        has $.prepend;

        method consumes() { TestMessage }
        method produces() { TestMessage }

        method transformer(Supply $incoming) {
            supply {
                whenever $incoming {
                    emit TestMessage.new(body => $!prepend ~ .body);
                }
            }
        }
    }

    method consumes() { TestMessage }
    method produces() { TestMessage }
    method connect(*%options) {
        start Transform.new(prepend => %options<prepend>)
    }
}

{
    my $comp = Crow.compose(TestConnector);
    ok $comp ~~ Crow::Connector, 'Composing just a connector produces a Crow::Connector';
    ok $comp ~~ Crow::CompositeConnector, 'More specifically, a Crow::CompositeConnector';
    is $comp.consumes, TestMessage, 'Composite connector has correct consumes';
    is $comp.produces, TestMessage, 'Composite connector has correct produces';

    my $in = supply { emit TestMessage.new(body => 'interested') }
    my $output = $comp.establish($in, prepend => 'un');
    isa-ok $output, Supply, 'Get a Supply back from composite connector';
    my @messages = $output.list;
    is @messages.elems, 1, 'Get a single message out';
    ok @messages[0] ~~ TestMessage, 'That message is a TestMessage';
    is @messages[0].body, 'uninterested',
        'Correct message, implying correct connect options were passed';
}

throws-like { Crow.compose(TestConnector, TestConnector) },
    X::Crow::Compose::OnlyOneConnector;
throws-like { Crow.compose(TestMessageSource, TestConnector) },
    X::Crow::Compose::SourceAndConnector;
throws-like { Crow.compose(TestConnector, CollectingTestSink) },
    X::Crow::Compose::SinkAndConnector;

{
    my $comp = Crow.compose(TestUppercaseTransform, TestConnector, TestTransform);
    ok $comp ~~ Crow::Connector, 'Connector with transform each side makes a Crow::Connector';
    ok $comp ~~ Crow::CompositeConnector, 'More specifically, a Crow::CompositeConnector';
    is $comp.consumes, TestMessage, 'Composite connector has correct consumes';
    is $comp.produces, TestBinaryMessage, 'Composite connector has correct produces';

    my $in = supply { emit TestMessage.new(body => 'complete') }
    my $output = $comp.establish($in, prepend => 'in');
    isa-ok $output, Supply, 'Get a Supply back from composite connector';
    my @messages = $output.list;
    is @messages.elems, 1, 'Get a single message out';
    ok @messages[0] ~~ TestBinaryMessage, 'That message is a TestBinaryMessage';
    is @messages[0].body.decode('utf-8'), 'inCOMPLETE',
        'Correct message, implying correct options passing and correct transforms';
}

done-testing;

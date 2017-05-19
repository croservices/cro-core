use Cro;
use Cro::Connector;
use Cro::Message;
use Cro::Replyable;
use Cro::Sink;
use Cro::Source;
use Cro::Transform;
use Test;

my class TestMessage does Cro::Message {
    has Str $.body;
}

throws-like { Cro.compose() }, X::Cro::Compose::Empty;
throws-like { Cro.compose(Any) }, X::Cro::Compose::InvalidType;
throws-like { Cro.compose(TestMessage) }, X::Cro::Compose::InvalidType;

my class TestMessageSource does Cro::Source {
    method produces() { TestMessage }
    method incoming() returns Supply:D {
        supply {
            emit TestMessage.new(body => 'korbačky');
            emit TestMessage.new(body => 'pivo');
        }
    }
}

{
    my $comp = Cro.compose(TestMessageSource);
    ok $comp ~~ Cro::Source, 'Composing just a source produces a Cro::Source';
    ok $comp ~~ Cro::CompositeSource, 'More specifically, a Cro::CompositeSource';
    is $comp.produces, TestMessage, 'Composite source has correct produces';
    my @incoming = $comp.incoming.list;
    is @incoming.elems, 2, 'Got two messages from the composite source';
    for @incoming {
        ok .isa(TestMessage), 'Message of correct type';
    }
    is @incoming>>.body, ('korbačky', 'pivo'), 'Messages have correct bodies';
}

my class TestBinaryMessage does Cro::Message {
    has Blob $.body;
}
my class TestTransform does Cro::Transform {
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
    my $comp = Cro.compose(TestMessageSource, TestTransform);
    ok $comp ~~ Cro::Source, 'Composing source and transform produces a Cro::Source';
    ok $comp ~~ Cro::CompositeSource, 'More specifically, a Cro::CompositeSource';
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

throws-like { Cro.compose(TestTransform, TestMessageSource) },
    X::Cro::Compose::SourceMustBeFirst;
throws-like { Cro.compose(TestMessageSource, TestMessageSource) },
    X::Cro::Compose::SourceMustBeFirst;

{
    my $comp = Cro.compose(TestTransform);
    ok $comp ~~ Cro::Transform, 'Composing just a transform produces a Cro::Transform';
    ok $comp ~~ Cro::CompositeTransform, 'More specifically, a Cro::CompositeTransform';
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

my class TestIntMessage does Cro::Message {
    has Int $.value;
}
my class AnotherTestTransform does Cro::Transform {
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
    my $comp = Cro.compose(TestTransform, AnotherTestTransform);
    ok $comp ~~ Cro::Transform, 'Composing two transforms produces a Cro::Transform';
    ok $comp ~~ Cro::CompositeTransform, 'More specifically, a Cro::CompositeTransform';
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

my class TestSink does Cro::Sink {
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
    my $comp = Cro.compose($sink);
    ok $comp ~~ Cro::Sink, 'Composing just a sink produces a Cro::Sink';
    ok $comp ~~ Cro::CompositeSink, 'More specifically, a Cro::CompositeSink';
    is $comp.consumes, TestIntMessage, 'Composite sink has correct consumes';
    my @fake-messages = (5, 37).map: { TestIntMessage.new(value => $_) };
    my $sink-supply = $comp.sinker(Supply.from-list(@fake-messages));
    isa-ok $sink-supply, Supply, 'Composite sink returns a Supply';
    is $sink-supply.list.elems, 0, 'Sink does not produce any messages';
    is $sink.sum, 42, 'Composite sink processed messages';
}

{
    my $sink = TestSink.new;
    my $comp = Cro.compose(TestTransform, AnotherTestTransform, $sink);
    ok $comp ~~ Cro::Sink, 'Composing transforms and sink produces a Cro::Sink';
    ok $comp ~~ Cro::CompositeSink, 'More specifically, a Cro::CompositeSink';
    is $comp.consumes, TestMessage, 'Composite sink has correct consumes';
    my @fake-messages = <máta hovězí>.map: { TestMessage.new(body => $_) };
    my $sink-supply = $comp.sinker(Supply.from-list(@fake-messages));
    isa-ok $sink-supply, Supply, 'Composite sink returns a Supply';
    is $sink-supply.list.elems, 0, 'Sink does not produce any messages';
    is $sink.sum, 13, 'Composite sink processed messages';
}

throws-like { Cro.compose(AnotherTestTransform, TestSink, TestTransform) },
    X::Cro::Compose::SinkMustBeLast;
throws-like { Cro.compose(TestSink, TestTransform) },
    X::Cro::Compose::SinkMustBeLast;
throws-like { Cro.compose(TestSink, TestMessageSource) },
    X::Cro::Compose::SinkMustBeLast;

{
    my $sink = TestSink.new;
    my $comp = Cro.compose(TestMessageSource, TestTransform, AnotherTestTransform, $sink);
    ok $comp ~~ Cro::Service, 'Composing source/transform/sink gives a Cro::Service';
    $comp.start();
    is $sink.sum, 13, 'Starting service processes all messages';
}

throws-like { Cro.compose(TestMessageSource, TestSink) },
    X::Cro::Compose::Mismatch,
    producer => TestMessageSource,
    consumer => TestSink;
throws-like { Cro.compose(TestMessageSource, AnotherTestTransform) },
    X::Cro::Compose::Mismatch,
    producer => TestMessageSource,
    consumer => AnotherTestTransform;
throws-like { Cro.compose(TestMessageSource, TestTransform, TestSink) },
    X::Cro::Compose::Mismatch,
    producer => TestTransform,
    consumer => TestSink;

my class NaughtySource does Cro::Source {
    method produces() { Int }
    method incoming() { supply { } }
}
my class NaughtyTransform1 does Cro::Transform {
    method consumes() { Int }
    method produces() { TestMessage }
    method transformer($pipeline) { supply { } }
}
my class NaughtyTransform2 does Cro::Transform {
    method consumes() { TestMessage }
    method produces() { Int }
    method transformer($pipeline) { supply { } }
}
my class NaughtySink does Cro::Sink {
    method consumes() { Int }
    method sinker($pipeline) { supply { } }
}
throws-like { Cro.compose(NaughtySource) },
    X::Cro::Compose::BadProducer,
    producer => NaughtySource;
throws-like { Cro.compose(NaughtyTransform1) },
    X::Cro::Compose::BadConsumer,
    consumer => NaughtyTransform1;
throws-like { Cro.compose(NaughtyTransform2) },
    X::Cro::Compose::BadProducer,
    producer => NaughtyTransform2;
throws-like { Cro.compose(NaughtySink) },
    X::Cro::Compose::BadConsumer,
    consumer => NaughtySink;

class TestReplyableSourceWithSink does Cro::Source does Cro::Replyable {
    has $.sinker = TestSink.new;
    method produces() { TestMessage }
    method incoming() returns Supply:D {
        supply {
            emit TestMessage.new(body => 'vánoce');
            emit TestMessage.new(body => 'stromek');
        }
    }
    method replier() returns Cro::Replier {
        $!sinker
    }
}

{
    my $test-reply-source = TestReplyableSourceWithSink.new();
    my $comp = Cro.compose($test-reply-source, TestTransform, AnotherTestTransform);
    ok $comp ~~ Cro::Service,
        'Composing source+transforms with sink from replyable source gives a Cro::Service';
    $comp.start();
    is $test-reply-source.sinker.sum, 14,
        'Starting service uses sink to consume messages';
}

{
    my $reply-source = TestReplyableSourceWithSink.new;
    my $sink = TestSink.new;
    throws-like {
            Cro.compose($reply-source, TestTransform, AnotherTestTransform, $sink)
        },
        X::Cro::Compose::TooManySinks,
        replyable => TestReplyableSourceWithSink,
        'Cannot have sink from replyable as well as sink already in the pipeline';
    throws-like {
            Cro.compose($reply-source, TestTransform)
        },
        X::Cro::Compose::Mismatch,
        producer => TestTransform,
        consumer => $reply-source.replier,
        'Sink from replyable must type match the last producer before it';
}

class TestReplyableSourceWithTransform1 does Cro::Source does Cro::Replyable {
    method produces() { TestMessage }
    method incoming() returns Supply:D {
        supply {
            emit TestMessage.new(body => 'vánoce');
            emit TestMessage.new(body => 'stromek');
        }
    }
    method replier() returns Cro::Replier {
        AnotherTestTransform
    }
}

{
    my $comp = Cro.compose(TestReplyableSourceWithTransform1, TestTransform);
    ok $comp ~~ Cro::Source,
        'Source replyable (transform to go at end) + transform produces Cro::Source';
    ok $comp ~~ Cro::CompositeSource, 'More specifically, a Cro::CompositeSource';
    is $comp.produces, TestIntMessage, 'Composite source has correct produces';
    my @incoming = $comp.incoming.list;
    is @incoming>>.value, [7, 7], 'Correct messages produced by transform';
}

class TestReplyableSourceWithTransform2 does Cro::Source does Cro::Replyable {
    method produces() { TestMessage }
    method incoming() returns Supply:D {
        supply {
            emit TestMessage.new(body => 'rajčata');
            emit TestMessage.new(body => 'česnek');
        }
    }
    method replier() returns Cro::Replier {
        TestTransform
    }
}

{
    my $comp = Cro.compose(TestReplyableSourceWithTransform2, AnotherTestTransform);
    ok $comp ~~ Cro::Source,
        'Source replyable (transform to go in middle) + transform produces Cro::Source';
    ok $comp ~~ Cro::CompositeSource, 'More specifically, a Cro::CompositeSource';
    is $comp.produces, TestIntMessage, 'Composite source has correct produces';
    my @incoming = $comp.incoming.list;
    is @incoming>>.value, [8, 7], 'Correct messages produced by transform';
}

class TestReplyableTransform does Cro::Transform does Cro::Replyable {
    method consumes() { TestMessage }
    method produces() { TestBinaryMessage }
    method transformer(Supply:D $in) returns Supply:D {
        supply {
            whenever $in -> $message {
                emit TestBinaryMessage.new(body => $message.body.encode('utf-8'));
            }
        }
    }
    method replier() returns Cro::Replier {
        AnotherTestTransform
    }
}

{
    my $test-reply-source = TestReplyableSourceWithSink.new();
    my $comp = Cro.compose($test-reply-source, TestReplyableTransform);
    ok $comp ~~ Cro::Service,
        'Source replyable (sink) + transform replyable (transform) gives Cro::Service';
    $comp.start();
    is $test-reply-source.sinker.sum, 14,
        'Service pipeline works correctly';
}

class BadReplyableTransform1 does Cro::Transform does Cro::Replyable {
    method consumes() { TestMessage }
    method produces() { TestBinaryMessage }
    method transformer(Supply:D $in) returns Supply:D {
        supply {
            whenever $in -> $message {
                emit TestBinaryMessage.new(body => $message.body.encode('utf-8'));
            }
        }
    }
    method replier() returns Cro::Replier {
        TestTransform
    }
}

{
    my $test-reply-source = TestReplyableSourceWithSink.new();
    throws-like {
            Cro.compose($test-reply-source, BadReplyableTransform1)
        },
        X::Cro::Compose::Mismatch,
        producer => BadReplyableTransform1,
        consumer => BadReplyableTransform1.replier,
        'Replyable with transform to be inserted at end with type mismatch throws';
}

class BadReplyableTransform2 does Cro::Transform does Cro::Replyable {
    method consumes() { TestMessage }
    method produces() { TestBinaryMessage }
    method transformer(Supply:D $in) returns Supply:D {
        supply {
            whenever $in -> $message {
                emit TestBinaryMessage.new(body => $message.body.encode('utf-8'));
            }
        }
    }
    method replier() returns Cro::Replier {
        TestSink.new
    }
}

{
    my $test-reply-source = TestReplyableSourceWithSink.new();
    throws-like {
            Cro.compose($test-reply-source, BadReplyableTransform2, AnotherTestTransform)
        },
        X::Cro::Compose::TooManySinks,
        replyable => $test-reply-source,
        'Cannot have two replyables that provide sinks';
}

class BadReplyableSource1 does Cro::Source does Cro::Replyable {
    method produces() { TestMessage }
    method incoming() returns Supply:D {
        supply { }
    }
    method replier() {
        TestMessageSource
    }
}
class BadReplyableSource2 does Cro::Source does Cro::Replyable {
    method produces() { TestMessage }
    method incoming() returns Supply:D {
        supply { }
    }
    method replier() {
        'lol not even a Cro::Thing'
    }
}
class BadReplyableTransform3 does Cro::Transform does Cro::Replyable {
    method consumes() { TestMessage }
    method produces() { TestBinaryMessage }
    method transformer(Supply:D $in) returns Supply:D {
        supply { }
    }
    method replier() {
        TestMessageSource
    }
}
class BadReplyableTransform4 does Cro::Transform does Cro::Replyable {
    method consumes() { TestMessage }
    method produces() { TestBinaryMessage }
    method transformer(Supply:D $in) returns Supply:D {
        supply { }
    }
    method replier() {
        'lol not even a Cro::Thing'
    }
}

{
    throws-like {
            Cro.compose(BadReplyableSource1, TestTransform)
        },
        X::Cro::Compose::BadReplier,
        replyable => BadReplyableSource1,
        'A replyable source cannot return a Cro::Source from replier';
    throws-like {
            Cro.compose(BadReplyableSource2, TestTransform)
        },
        X::Cro::Compose::BadReplier,
        replyable => BadReplyableSource2,
        'A replyable source must return a Cro::Transform or a Cro::Sink';
    throws-like {
            Cro.compose(BadReplyableTransform3, AnotherTestTransform)
        },
        X::Cro::Compose::BadReplier,
        replyable => BadReplyableTransform3,
        'A replyable transform cannot return a Cro::Source from replier';
    throws-like {
            Cro.compose(BadReplyableTransform4, AnotherTestTransform)
        },
        X::Cro::Compose::BadReplier,
        replyable => BadReplyableTransform4,
        'A replyable transform must return a Cro::Transform or a Cro::Sink';
}

my class TestConnection does Cro::Connection does Cro::Replyable {
    has Supplier $.send .= new;
    has Supplier $!replier .= new;
    method receive() { $!replier.Supply }

    method produces() { TestMessage }
    method incoming() { $!send.Supply }

    method replier() {
        class :: does Cro::Sink {
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
my class TestConnectionSource does Cro::Source {
    has Supplier $.connection-injection .= new;
    method produces() { TestConnection }
    method incoming() {
        $!connection-injection.Supply
    }
}
my class TestUppercaseTransform does Cro::Transform {
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
    my $service = Cro.compose($conn-source, TestUppercaseTransform);
    ok $service ~~ Cro::Service,
        'Connection source with replyable connection and transform makes a Cro::Service';
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
    my $service = Cro.compose($conn-source);
    ok $service ~~ Cro::Service,
        'Connection source with replyable connection makes a Cro::Service';
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

my class NonReplyableTestConnection does Cro::Connection {
    has Supplier $.send .= new;
    method produces() { TestMessage }
    method incoming() { $!send.Supply }
}
my class NonReplyableTestConnectionSource does Cro::Source {
    has Supplier $.connection-injection .= new;
    method produces() { NonReplyableTestConnection }
    method incoming() {
        $!connection-injection.Supply
    }
}

{
    my $conn-source = NonReplyableTestConnectionSource.new();
    throws-like { Cro.compose($conn-source, TestUppercaseTransform) },
        X::Cro::ConnectionManager::Misuse,
        'Connection manager cannot be formed if there is no sink';
}

my class CollectingTestSink does Cro::Sink {
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
    my $service = Cro.compose($conn-source, $sink);
    ok $service ~~ Cro::Service,
        'Connection source and sink make a Cro::Service';
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
    my $service = Cro.compose($conn-source, TestUppercaseTransform, $sink);
    ok $service ~~ Cro::Service,
        'Connection source, transform, and sink make a Cro::Service';
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
    throws-like { Cro.compose($conn-source, CollectingTestSink.new) },
        X::Cro::ConnectionManager::Misuse,
        'Cannot have an explicit sink and a replyable connection';
}

my class BlockableTestMessage does Cro::Message {
    has Promise $.blocker .= new;
    has Str $.body;
}
my class BlockableTestConnection does Cro::Connection does Cro::Replyable {
    has Supplier $.send .= new;
    has Supplier $!replier .= new;
    method receive() { $!replier.Supply }

    method produces() { BlockableTestMessage }
    method incoming() { $!send.Supply }

    method replier() {
        class :: does Cro::Sink {
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
my class BlockableTestConnectionSource does Cro::Source {
    has Supplier $.connection-injection .= new;
    method produces() { BlockableTestConnection }
    method incoming() {
        $!connection-injection.Supply
    }
}
my class BlockingTransform does Cro::Transform {
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
    my $service = Cro.compose($conn-source, BlockingTransform);
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

my class TestConnector does Cro::Connector {
    class Transform does Cro::Transform {
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
    my $comp = Cro.compose(TestConnector);
    ok $comp ~~ Cro::Connector, 'Composing just a connector produces a Cro::Connector';
    ok $comp ~~ Cro::CompositeConnector, 'More specifically, a Cro::CompositeConnector';
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

throws-like { Cro.compose(TestConnector, TestConnector) },
    X::Cro::Compose::OnlyOneConnector;
throws-like { Cro.compose(TestMessageSource, TestConnector) },
    X::Cro::Compose::SourceAndConnector;
throws-like { Cro.compose(TestConnector, CollectingTestSink) },
    X::Cro::Compose::SinkAndConnector;

{
    my $comp = Cro.compose(TestUppercaseTransform, TestConnector, TestTransform);
    ok $comp ~~ Cro::Connector, 'Connector with transform each side makes a Cro::Connector';
    ok $comp ~~ Cro::CompositeConnector, 'More specifically, a Cro::CompositeConnector';
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

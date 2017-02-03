use Crow;
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
    isa-ok $comp, Crow::Service, 'Composing source/transform/sink gives a Crow::Service';
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
    isa-ok $comp, Crow::Service,
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
    isa-ok $comp, Crow::Service,
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


done-testing;

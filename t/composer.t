use Crow;
use Crow::Source;
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

done-testing;

use Cro::Sink;
use Cro::Transform;
use Cro;
use Test;

my class TestMessageA does Cro::Message { }
my class TestMessageB does Cro::Message { }
my class TestMessageC does Cro::Message {
    has Str $.message
}

my class TestTransform1 does Cro::Transform {
    method consumes() { TestMessageA }
    method produces() { TestMessageC }
    method transformer($pipeline) {
        supply {
            whenever $pipeline {
                emit TestMessageC.new(:message('t1'));
            }
        }
    }
}
my class TestTransform2 does Cro::Transform {
    method consumes() { TestMessageA }
    method produces() { TestMessageB }
    method transformer($pipeline) {
        supply {
            whenever $pipeline {
                emit TestMessageB.new();
            }
        }
    }
}
my class TestTransform3 does Cro::Transform {
    method consumes() { TestMessageB }
    method produces() { TestMessageC }
    method transformer($pipeline) {
        supply {
            whenever $pipeline {
                emit TestMessageC.new(:message('t3'));
            }
        }
    }
}
my class TestSink does Cro::Sink {
    method consumes() { TestMessageC }
    method sinker() { ... }
}

throws-like { Cro::ConnectionConditional.new },
    X::Cro::ConnectionConditional::NoAlternatives,
    'Must construct connection conditional with at least one alternative';
lives-ok { Cro::ConnectionConditional.new(TestTransform1) },
    'Can construct with a single transform as default';
lives-ok { Cro::ConnectionConditional.new([TestTransform2, TestTransform3]) },
    'Can construct with a single array of transform as default';
throws-like { Cro::ConnectionConditional.new(TestSink) },
    X::Cro::ConnectionConditional::TransformOnly,
    got => TestSink,
    'Cannot construct with a non-transform default';
throws-like { Cro::ConnectionConditional.new([TestTransform3, TestSink]) },
    X::Cro::ConnectionConditional::TransformOnly,
    got => TestSink,
    'Cannot construct with an array containing a non-transform default';
throws-like { Cro::ConnectionConditional.new([TestTransform3, TestTransform2]) },
    X::Cro::Compose::Mismatch,
    'Cannot construct with an array where the transforms do not match up';

lives-ok
    {
        Cro::ConnectionConditional.new(
            {.cond} => [TestTransform2, TestTransform3],
            TestTransform1
        )
    },
    'Can have a condition and a default, where the resulting produce/consume matches';
throws-like
    {
        Cro::ConnectionConditional.new(
            {.cond} => TestSink,
            TestTransform1
        )
    },
    X::Cro::ConnectionConditional::TransformOnly,
    got => TestSink,
    'Cannot construct with a non-transform in a condition';
throws-like
    {
        Cro::ConnectionConditional.new(
            {.cond} => [TestTransform3, TestSink],
            TestTransform1
        )
    },
    X::Cro::ConnectionConditional::TransformOnly,
    got => TestSink,
    'Cannot construct with a non-transform in a condition array';
throws-like
    {
        Cro::ConnectionConditional.new(
            {.cond} => [TestTransform3, TestTransform2],
            TestTransform1
        )
    },
    X::Cro::Compose::Mismatch,
    'Cannot construct with a non-compatible transforms in a condition array';

throws-like
    {
        Cro::ConnectionConditional.new(
            {.cond} => [TestTransform2, TestTransform3]
        )
    },
    X::Cro::ConnectionConditional::NoDefault,
    'Cannot have a connection conditional with no default';
throws-like
    {
        Cro::ConnectionConditional.new(
            [TestTransform2, TestTransform3],
            TestTransform1
        )
    },
    X::Cro::ConnectionConditional::MultipleDefaults,
    'Cannot have a connection conditional with multiple defaults';

throws-like
    {
        Cro::ConnectionConditional.new(
            {.cond} => TestTransform2,
            TestTransform1
        )
    },
    X::Cro::ConnectionConditional::Incompatible,
    consumes-a => TestMessageA,
    produces-a => TestMessageB,
    consumes-b => TestMessageA,
    produces-b => TestMessageC,
    'Cannot have conditions/default with incompatible pipelines';

{
    my $cc = Cro::ConnectionConditional.new(
        {.cond} => [TestTransform2, TestTransform3],
        TestTransform1
    );
    is $cc.consumes, TestMessageA, 'Consumes set correctly on result object';
    is $cc.produces, TestMessageC, 'Produces set correctly on result object';

    my class TestCond {
        has $.cond;
    }
    my \result-a = $cc.select(TestCond.new(:cond));
    is-deeply result-a, [TestTransform2, TestTransform3],
        'Correct choice when condition matches';
    my \result-b = $cc.select(TestCond.new(:!cond));
    is result-b, TestTransform1,
        'Correct choice when condition does not match';

    throws-like { Cro.compose($cc) },
        X::Cro::Compose::ConnectionConditionalWithoutConnector,
        'Can only compose a ConnectionConditional in a pipeline containing a connector';

    my class TestConnector does Cro::Connector {
        my class Transform does Cro::Transform {
            has $.cond;

            method consumes() { TestMessageC }
            method produces() { TestMessageC }

            method transformer($pipeline) {
                supply {
                    whenever $pipeline {
                        .emit;
                    }
                }
            }
        }

        method consumes() { TestMessageC }
        method produces() { TestMessageC }
        method connect(*%options --> Promise) {
            start Transform.new(:cond(%options<cond>))
        }
    }
    my $pipeline;
    lives-ok { $pipeline = Cro.compose($cc, TestConnector) },
        'Can compose a pipeline containing a connection conditional and a connector';
    ok $pipeline ~~ Cro::Connector, 'We get back a Cro::Connector';
    ok $pipeline ~~ Cro::CompositeConnector, 'We get back a Cro::CompositeConnector';

    my $in1 = Supplier::Preserving.new;
    my $conn1 = $pipeline.establish($in1.Supply, :cond).Channel;
    $in1.emit(TestMessageA.new);
    is $conn1.receive.message, 't3', 'Conditional correctly evaluated to option';

    my $in2 = Supplier::Preserving.new;
    my $conn2 = $pipeline.establish($in2.Supply, :!cond).Channel;
    $in2.emit(TestMessageA.new);
    is $conn2.receive.message, 't1', 'Conditional correctly evaluated to default';
}

done-testing;

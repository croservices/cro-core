use Cro;
use Test;

my class TestMessage does Cro::Message {
    has Str $.message
}

my class TestState {
    has $.was-chars is rw = 0;
}

my class TestTransform1 does Cro::Transform does Cro::ConnectionState[TestState] {
    method consumes() { TestMessage }
    method produces() { TestMessage }
    method transformer($pipeline, TestState :$connection-state!) {
        supply {
            whenever $pipeline {
                $connection-state.was-chars += .message.chars;
                emit TestMessage.new(:message(.message x 2));
            }
        }
    }
}
my class TestTransform2 does Cro::Transform does Cro::ConnectionState[TestState] {
    method consumes() { TestMessage }
    method produces() { TestMessage }
    method transformer($pipeline, TestState :$connection-state!) {
        supply {
            whenever $pipeline {
                emit TestMessage.new(:message(.message ~ $connection-state.was-chars));
            }
        }
    }
}

my class TestConnector does Cro::Connector {
    my class Transform does Cro::Transform {
        method consumes() { TestMessage }
        method produces() { TestMessage }

        method transformer($pipeline) {
            supply {
                whenever $pipeline {
                    .emit;
                }
            }
        }
    }

    method consumes() { TestMessage }
    method produces() { TestMessage }
    method connect(*%options --> Promise) {
        start Transform.new()
    }
}

throws-like { Cro.compose(TestTransform1) },
    X::Cro::Compose::ConnectionStateWithoutConnection,
    'Connection state only makes sense in the scope of a connection';

{
    my $pipeline;
    lives-ok { $pipeline = Cro.compose(TestTransform1, TestConnector, TestTransform2) },
        'Can compose components with connection state with a connector';
    ok $pipeline ~~ Cro::Connector, 'Result is a Cro::Connector';
    ok $pipeline ~~ Cro::CompositeConnector, 'Result is a Cro::CompositeConnector';

    my $in1 = Supplier::Preserving.new;
    my $conn1 = $pipeline.establish($in1.Supply).Channel;
    $in1.emit(TestMessage.new(:message('jar')));
    is $conn1.receive.message, 'jarjar3', 'State object shared between components';
    $in1.emit(TestMessage.new(:message('jar')));
    is $conn1.receive.message, 'jarjar6', 'State object lives for whole connection';

    my $in2 = Supplier::Preserving.new;
    my $conn2 = $pipeline.establish($in2.Supply).Channel;
    $in2.emit(TestMessage.new(:message('jar')));
    is $conn2.receive.message, 'jarjar3', 'State object is fresh per connection';
}

{
    my $tran = Cro.compose(TestTransform1, TestTransform2, :for-connection);
    ok $tran ~~ Cro::CompositeTransform,
        'Explicit :for-connection option to compose accepts connection state';

    my $in1 = Supplier::Preserving.new;
    my $pipeline1 = $tran.transformer($in1.Supply).Channel;
    $in1.emit(TestMessage.new(:message('jar')));
    is $pipeline1.receive.message, 'jarjar3', 'State object shared between components';
    $in1.emit(TestMessage.new(:message('jar')));
    is $pipeline1.receive.message, 'jarjar6', 'State object lives for whole transformation';

    my $in2 = Supplier::Preserving.new;
    my $pipeline2 = $tran.transformer($in2.Supply).Channel;
    $in2.emit(TestMessage.new(:message('jar')));
    is $pipeline2.receive.message, 'jarjar3', 'State object is fresh per connection';
}

done-testing;

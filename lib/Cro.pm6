use Cro::Connection;
use Cro::Connector;
use Cro::Message;
use Cro::Replyable;
use Cro::Service;
use Cro::Sink;
use Cro::Source;
use Cro::Transform;

class X::Cro::Compose::Empty is Exception {
    method message() { "Cannot compose an empty list of components" }
}
class X::Cro::Compose::InvalidType is Exception {
    has $.invalid;
    method message() {
        "Cannot compose $!invalid.^name() into a Cro pipeline; it does not " ~
        "do Cro::Source, Cro::Transform, Cro::Sink, or Cro::Connector"
    }
}
class X::Cro::Compose::SourceMustBeFirst is Exception {
    has $.source;
    method message() {
        "A Cro::Source must occur at the start of a pipeline, but " ~
        $!source.^name() ~ " is placed later"
    }
}
class X::Cro::Compose::SinkMustBeLast is Exception {
    has $.sink;
    method message() {
        "A Cro::Sink must occur at the end of a pipeline, but " ~
        $!sink.^name() ~ " is placed earlier"
    }
}
class X::Cro::Compose::Mismatch is Exception {
    has $.producer;
    has $.consumer;
    method message() {
        "Cannot compose a $!producer.^name() producing $!producer.produces.^name() " ~
        "with a $!consumer.^name() consuming a $!consumer.consumes.^name()"
    }
}
class X::Cro::Compose::BadProducer is Exception {
    has $.producer;
    method message() {
        "Cannot compose $!producer.^name(); it produces $!producer.produces.^name() " ~
        "which is neither a Cro::Message nor a Cro::Connection"
    }
}
class X::Cro::Compose::BadConsumer is Exception {
    has $.consumer;
    method message() {
        "Cannot compose $!consumer.^name(); it consumes $!consumer.consumes.^name() " ~
        "which is neither a Cro::Message nor a Cro::Connection"
    }
}
class X::Cro::Compose::BadReplier is Exception {
    has $.replyable;
    method message() {
        my $replier = $!replyable.replier;
        "Replyable component $!replyable.^name() has a replier method returning a " ~
        "$replier.^name(), which is neither a Cro::Transform nor a Cro::Sink"
    }
}
class X::Cro::Compose::TooManySinks is Exception {
    has $.replyable;
    method message() {
        "Cannot apply sink $!replyable.replier.^name() from $!replyable.^name() " ~
        "because this pipeline already has a sink"
    }
}
class X::Cro::Compose::OnlyOneConnector is Exception {
    method message() {
        "Cannot compose a pipeline with more than one connector"
    }
}
class X::Cro::Compose::SourceAndConnector is Exception {
    method message() {
        "A pipeline with a connector may not also have a source"
    }
}
class X::Cro::Compose::SinkAndConnector is Exception {
    method message() {
        "A pipeline with a connector may not also have a sink"
    }
}
class X::Cro::ConnectionManager::Misuse is Exception {
    has $.message;
}

class Cro { ... }

class Cro::CompositeSource does Cro::Source {
    has @.components is required;

    method produces() { @!components.tail.produces }

    method incoming() returns Supply:D {
        my ($source, @rest) = @!components;
        my $current = $source.incoming;
        for @rest {
            $current = .transformer($current);
        }
        return $current;
    }
}

class Cro::CompositeTransform does Cro::Transform {
    has @.components is required;

    method consumes() { @!components.head.consumes }
    method produces() { @!components.tail.produces }

    method transformer(Supply:D $pipeline) returns Supply:D {
        my $current = $pipeline;
        for @!components {
            $current = .transformer($current);
        }
        return $current;
    }
}

class Cro::CompositeSink does Cro::Sink {
    has @.components is required;

    method consumes() { @!components.head.consumes }

    method sinker(Supply:D $pipeline) returns Supply:D {
        my @transforms = @!components;
        my $sink = @transforms.pop;
        my $current = $pipeline;
        for @transforms {
            $current = .transformer($current);
        }
        return $sink.sinker($current);
    }
}

class Cro::CompositeConnector does Cro::Connector {
    has @!before;
    has $!connector;
    has @!after;

    submethod BUILD(:@components! --> Nil) {
        my $seen-connector = False;
        for @components {
            when Cro::Connector {
                $!connector = $_;
                $seen-connector = True;
            }
            when $seen-connector {
                @!after.push($_);
            }
            default {
                @!before.push($_);
            }
        }
    }

    method consumes() {
        (@!before ?? @!before[0] !! $!connector).consumes
    }

    method produces() {
        (@!after ?? @!after[*-1] !! $!connector).produces
    }

    method connect(*%options --> Promise) {
        start {
            my Cro::Transform $con-tran = await $!connector.connect(|%options);
            Cro::CompositeTransform.new(components => flat(@!before, $con-tran, @!after))
        }
    }
}

class Cro::ConnectionManager does Cro::Sink {
    has Cro::Connection:U $!connection-type;
    has Cro::Transform $!transformer;
    has Cro::Sink $!sinker;

    submethod BUILD(:$!connection-type, :@components) {
        if @components {
            given Cro.compose(@components) {
                when Cro::Sink {
                    if $!connection-type ~~ Cro::Replyable {
                        die X::Cro::ConnectionManager::Misuse.new: message =>
                            "A connection manager was inserted before after " ~
                            "component {@components[0].^name}. The connection " ~
                            "type {$!connection-type.^name} is replyable, but " ~
                            "an explicit sink was also provided in the following " ~
                            "components"
                    }
                    else {
                        $!sinker = $_;
                    }
                }
                when Cro::Transform {
                    if $!connection-type ~~ Cro::Replyable {
                        $!transformer = $_;
                    }
                    else {
                        die X::Cro::ConnectionManager::Misuse.new: message =>
                            "A connection manager was inserted before component " ~
                            "{@components[0].^name}, but the connection was not " ~
                            "replyable and the remaining components did not finish " ~
                            "with a sink"
                    }
                }
                default {
                    die X::Cro::ConnectionManager::Misuse.new: message =>
                        "Components controlled by a connection manager must " ~
                        "compose to form a transform or a sink"
                }
            }
        }
        elsif $!connection-type !~~ Cro::Replyable {
            die X::Cro::ConnectionManager::Misuse.new: message =>
                "Can only create a connection manager from an empty list of " ~
                "components if the source connection type is replyable"
        }
    }

    method consumes() { $!connection-type }

    method sinker(Supply:D $incoming) {
        $incoming.do: -> $connection {
            my $messages = $connection.incoming;
            my $to-sink = $!transformer
                ?? $!transformer.transformer($messages)
                !! $messages;
            my $sink = $!sinker
                ?? $!sinker.sinker($to-sink)
                !! $connection.replier.sinker($to-sink);
            $sink.tap: quit => { .note };
        }
    }
}

class Cro {
    my subset ConnectionOrMessage where Cro::Message | Cro::Connection;

    method compose(*@components-in, Cro::Service :$service-type) {
        die X::Cro::Compose::Empty.new unless @components-in;

        # First scan through and see if we need to insert a connection
        # manager, which happens whenever there's a component that produces
        # connections, which are in turn consumed by something that wants to
        # get messages of the type the connection produces. We also do this if
        # the connection-producing thing comes last and is replyable.
        for flat @components-in Z @components-in[1..*] -> $comp, $next {
            ++state $split;
            if $comp.?produces ~~ Cro::Connection {
                if $comp.produces.produces === $next.?consumes {
                    return Cro.compose:
                        |@components-in[^$split],
                        Cro::ConnectionManager.new(
                            connection-type => $comp.produces,
                            components => @components-in[$split..*]
                        );
                }
            }
        }
        given @components-in[*-1] -> $comp {
            if $comp ~~ Cro::Source && $comp.produces ~~ Cro::Connection {
                if $comp.produces ~~ Cro::Replyable {
                    return Cro.compose:
                        |@components-in,
                        Cro::ConnectionManager.new(
                            connection-type => $comp.produces,
                            components => []
                        );
                }
            }
        }

        my $has-source = False;
        my $has-sink = False;
        my $has-connector = False;
        my $expected;
        my @repliers-to-insert;
        my @components;

        sub check-and-add-replyable(Cro::Replyable $replyable) {
            my $replier = $replyable.replier;
            if $replier !~~ Cro::Transform && $replier !~~ Cro::Sink {
                die X::Cro::Compose::BadReplier.new(:$replyable);
            }
            @repliers-to-insert.unshift($replyable);
        }
        sub validate-consumer($consumer) {
            unless $consumer.consumes ~~ ConnectionOrMessage {
                die X::Cro::Compose::BadConsumer.new(:$consumer);
            }
        }
        sub validate-producer($producer) {
            unless $producer.produces ~~ ConnectionOrMessage {
                die X::Cro::Compose::BadProducer.new(:$producer);
            }
        }

        for @components-in.kv -> $i, $comp {
            if @repliers-to-insert {
                my $replyable = @repliers-to-insert[0];
                my $replier = $replyable.replier;
                if $replier ~~ Cro::Transform && $replier.consumes === $expected {
                    shift @repliers-to-insert;
                    push @components, $replier;
                    $expected = $replier.produces;
                }
            }

            given $comp {
                when Cro::Source {
                    unless $i == 0 {
                        die X::Cro::Compose::SourceMustBeFirst.new(source => $comp);
                    }
                    validate-producer($_);
                    $has-source = True;
                    when Cro::Replyable {
                        check-and-add-replyable($_);
                    }
                }
                when Cro::Transform {
                    validate-consumer($_);
                    validate-producer($_);
                    when Cro::Replyable {
                        check-and-add-replyable($_);
                    }
                }
                when Cro::Connector {
                    die X::Cro::Compose::OnlyOneConnector.new if $has-connector;
                    validate-consumer($_);
                    validate-producer($_);
                    $has-connector = True;
                }
                when Cro::Sink {
                    unless $i == @components-in.end {
                        die X::Cro::Compose::SinkMustBeLast.new(sink => $comp);
                    }
                    validate-consumer($_);
                    $has-sink = True;
                }
                default {
                    die X::Cro::Compose::InvalidType.new(invalid => $comp);
                }
            }

            if $i == 0 {
                $expected = $comp.?produces;
            }
            elsif $comp.consumes !=== $expected {
                die X::Cro::Compose::Mismatch.new(
                    producer => @components[* - 1],
                    consumer => $comp
                );
            }
            else {
                $expected = $comp.?produces;
            }

            push @components, $comp;
        }

        for @repliers-to-insert -> $replyable {
            given $replyable.replier {
                when Cro::Sink {
                    if $has-sink {
                        die X::Cro::Compose::TooManySinks.new(:$replyable);
                    }
                    if .consumes !=== $expected {
                        die X::Cro::Compose::Mismatch.new(
                            producer => @components[* - 1],
                            consumer => $_
                        );
                    }
                    push @components, $_;
                    $has-sink = True;
                }
                when Cro::Transform {
                    if .consumes !=== $expected {
                        die X::Cro::Compose::Mismatch.new(
                            producer => @components[* - 1],
                            consumer => $_
                        );
                    }
                    push @components, $_;
                    $expected = .produces;
                }
            }
        }

        if $has-connector {
            die X::Cro::Compose::SourceAndConnector.new if $has-source;
            die X::Cro::Compose::SinkAndConnector.new if $has-sink;
            Cro::CompositeConnector.new(:@components)
        }
        elsif $has-source && $has-sink {
            $service-type.bless(:@components)
        }
        elsif $has-source {
            Cro::CompositeSource.new(:@components)
        }
        elsif $has-sink {
            Cro::CompositeSink.new(:@components)
        }
        else {
            Cro::CompositeTransform.new(:@components)
        }
    }
}

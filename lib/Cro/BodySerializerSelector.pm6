use Cro::BodySerializer;
use Cro::MessageWithBody;

class X::Cro::BodySerializerSelector::NoneApplicable is Exception {
    method message() {
        "No applicable body serializer could be found for this message"
    }
}

role Cro::BodySerializerSelector {
    method select(Cro::MessageWithBody $body --> Cro::BodySerializer) { ... }
}

class Cro::BodySerializerSelector::List does Cro::BodySerializerSelector {
    has Cro::BodySerializer @.serializers;

    method select(Cro::MessageWithBody $message, $body --> Cro::BodySerializer) {
        for @!serializers {
            .return if .is-applicable($message, $body);
        }
        die X::Cro::BodySerializerSelector::NoneApplicable.new;
    }
}

class Cro::BodySerializerSelector::Prepend does Cro::BodySerializerSelector {
    has Cro::BodySerializer @.serializers;
    has Cro::BodySerializerSelector $.next is required;

    method select(Cro::MessageWithBody $message, $body --> Cro::BodySerializer) {
        for @!serializers {
            .return if .is-applicable($message, $body);
        }
        $!next.select($message, $body);
    }
}

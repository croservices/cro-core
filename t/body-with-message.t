use Cro::BodyParserSelector;
use Cro::BodySerializerSelector;
use Cro::Message;
use Cro::MessageWithBody;
use Test;

ok Cro::MessageWithBody ~~ Cro::Message, 'Cro::MessageWithBody is a Cro::Message';

my class TestBodyA does Cro::MessageWithBody {
    method body-parser-selector() { die X::Cro::BodyParserSelector::NoneApplicable.new }
    method body-serializer-selector() { die X::Cro::BodySerializerSelector::NoneApplicable.new }
}

my $testBodyA = TestBodyA.new;
$testBodyA.set-body-byte-stream: supply {
    emit Blob.new(0x63, 0x72, 0x6f, 0x20, 0x62);
    emit Blob.new(0x6f, 0x64, 0x79);
}
given await $testBodyA.body-blob -> $blob {
    ok $blob ~~ Blob, 'body-blob method gives a Blob';
    is $blob.decode('ascii'), 'cro body', 'Blob has correct contents';
}

throws-like { await(TestBodyA.new.body-text) }, X::Cro::BodyNotText,
    'By default, asking for body-text gets an exception';

my class TestBodyB does Cro::MessageWithBody {
    method body-text-encoding(Blob $body) { 'ascii' }
    method body-parser-selector() { die X::Cro::BodyParserSelector::NoneApplicable.new }
    method body-serializer-selector() { die X::Cro::BodySerializerSelector::NoneApplicable.new }
}

my $testBodyB = TestBodyB.new;
$testBodyB.set-body-byte-stream: supply {
    emit Blob.new(0x63, 0x72, 0x6f, 0x20, 0x62);
    emit Blob.new(0x6f, 0x64, 0x79);
}
given await $testBodyB.body-text -> $str {
    ok $str ~~ Str, 'body-text method gives a Str';
    is $str, 'cro body', 'Str has correct value';
}

done-testing;

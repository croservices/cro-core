use Cro::Message;
use Cro::MessageWithBody;
use Test;

ok Cro::MessageWithBody ~~ Cro::Message, 'Cro::MessageWithBody is a Cro::Message';

my class TestBodyA does Cro::MessageWithBody {
    method body-byte-stream(--> Supply) {
        supply {
            emit Blob.new(0x63, 0x72, 0x6f, 0x20, 0x62);
            emit Blob.new(0x6f, 0x64, 0x79);
        }
    }
}

given await TestBodyA.new.body-blob -> $blob {
    ok $blob ~~ Blob, 'body-blob method gives a Blob';
    is $blob.decode('ascii'), 'cro body', 'Blob has correct contents';
}

throws-like { await(TestBodyA.new.body-text) }, X::Cro::BodyNotText,
    'By default, asking for body-text gets an exception';

my class TestBodyB does Cro::MessageWithBody {
    method body-byte-stream(--> Supply) {
        supply {
            emit Blob.new(0x63, 0x72, 0x6f, 0x20, 0x62);
            emit Blob.new(0x6f, 0x64, 0x79);
        }
    }

    method body-text-encoding(Blob $body) { 'ascii' }
}

given await TestBodyB.new.body-text -> $str {
    ok $str ~~ Str, 'body-text method gives a Str';
    is $str, 'cro body', 'Str has correct value';
}

done-testing;

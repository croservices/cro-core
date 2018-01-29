use Cro::Message;
use Cro::MessageWithBody;
use Test;

ok Cro::MessageWithBody ~~ Cro::Message, 'Cro::MessageWithBody is a Cro::Message';

my class TestBody does Cro::MessageWithBody {
    method body-byte-stream(--> Supply) {
        supply {
            emit Blob.new(0x63, 0x72, 0x6f, 0x20, 0x62);
            emit Blob.new(0x6f, 0x64, 0x79);
        }
    }
}

given await TestBody.new.body-blob -> $blob {
    ok $blob ~~ Blob, 'body-blob method gives a Blob';
    is $blob.decode('ascii'), 'cro body', 'Blob has correct contents';
}

done-testing;

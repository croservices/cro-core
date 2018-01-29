use Cro::Message;

role Cro::MessageWithBody does Cro::Message {
    method body-byte-stream(--> Supply) { ... }

    method body-blob(--> Promise) {
        Promise(supply {
            my $joined = Buf.new;
            whenever self.body-byte-stream -> $blob {
                $joined.append($blob);
                LAST emit $joined;
            }
        })
    }
}

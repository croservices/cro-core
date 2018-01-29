use Cro::Message;

class X::Cro::BodyNotText is Exception {
    has $.message;
    method message() { "$!message.^name() does not have a text body" }
}

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

    method body-text(--> Promise) {
        self.body-blob.then: -> $blob-promise {
            my $blob = $blob-promise.result;
            given self.body-text-encoding($blob) {
                when Str {
                    $blob.decode($_)
                }
                when Iterable {
                    my $result;
                    my $error;
                    for @$_ -> $try-enc {
                        $result = $blob.decode($try-enc);
                        CATCH {
                            default {
                                $error = $_;
                            }
                        }
                    }
                    $result // $error.rethrow
                }
                default {
                    die X::Cro::BodyNotText.new(message => self);
                }
            }
        }
    }

    method body-text-encoding(Blob $body) {
        die X::Cro::BodyNotText.new(message => self);
    }
}

class X::Cro::MediaType::Invalid is Exception {
    has Str $.media-type;
    method message() { "Could not parse media type '$!media-type'" }
}

class Cro::MediaType {
    has Str $.type is required;
    has Str $.suffix = '';
    has Str $.subtype-name is required;
    has Str $.tree = '';
    has Pair @.parameters;

    grammar Grammar {
        token TOP { <type> '/' <subtype> <parameters> \s* ';'? }
        token type { <[A..Za..z0..9_-]>+ }
        token subtype {
            [
            | $<name>=[<[A..Za..z0..9_-]>+]
            | $<tree>=[<[A..Za..z0..9_-]>+] '.' $<name>=[<[A..Za..z0..9_.-]>+]
            ]
            [ '+' $<suffix>=[<[A..Za..z0..9_-]>+] ]?
        }
        token parameters {
            [\s* ';' \s* <parameter>]*
        }
        token parameter {
            <attribute=.token> '=' <value>
        }
        proto token value {*}
        token value:sym<token> {
            <token>
        }
        token value:sym<quoted-string> {
            '"' ~ '"' [<qtext> | <quoted-pair>]*
        }
        token qtext { <-["\\\n]>+ }
        token quoted-pair { \\ <( . )> }
        token token { <[A..Za..z0..9!#$%&'*+^_`{|}~-]>+ }
    }

    class Actions {
        method TOP($/) {
            make Cro::MediaType.bless(
                type => ~$<type>,
                |$<subtype>.ast,
                parameters => $<parameters>.ast
            );
        }
        method subtype($/) {
            my %parts = 'subtype-name' => ~$<name>;
            %parts<tree> = ~$<tree> if $<tree>;
            %parts<suffix> = ~$<suffix> if $<suffix>;
            make %parts;
        }
        method parameters($/) {
            make $<parameter>.map(*.ast);
        }
        method parameter($/) {
            make ~$<attribute> => $<value>.ast;
        }
        method value:sym<token>($/) {
            make ~$/;
        }
        method value:sym<quoted-string>($/) {
            make $/.caps.map(*.value.Str).join;
        }
    }

    method parse(Str() $media-type --> Cro::MediaType) {
        with Grammar.parse($media-type, :actions(Actions)) {
            .ast
        }
        else {
            die X::Cro::MediaType::Invalid.new(:$media-type)
        }
    }

    method subtype() {
        ($!tree ?? "$!tree." !! "") ~
            $!subtype-name ~
            ($!suffix ?? "+$!suffix" !! "")
    }

    method type-and-subtype() {
        "$!type/$.subtype"
    }

    multi method Str(Cro::MediaType:D:) {
        "$!type/$.subtype" ~ @!parameters.map(&param-str).join
    }

    sub param-str(Pair $p) {
        my $prefix = "; $p.key()=";
        my $value = $p.value;
        Grammar.parse($value, :rule<token>)
            ?? "$prefix$value"
            !! qq[$prefix"$value.subst('"', '\\"', :g)"]
    }
}

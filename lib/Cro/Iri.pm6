use Cro::Uri :decode-percents, :encode-percents;
use Cro::ResourceIdentifier;

class X::Cro::Iri::ParseError is Exception {
    has $.reason = 'malformed syntax';
    has $.iri-string is required;
    method message() {
        "Unable to parse IRI '$!iri-string': $!reason"
    }
}

class Cro::Iri does Cro::ResourceIdentifier {
    grammar GenericParser is Cro::Uri::GenericParser {
        token TOP {
            <IRI>
        }

        token IRI {
            [<scheme> || <.panic('Malformed scheme')>]
            [":" || <.panic('Missing : after scheme')>]
            <ihier-part>
            ["?" <iquery>]?
            ["#" <ifragment>]?
            [$ || <.panic('unexpected text at end')>]
        }

        proto token ihier-part {*}
        token ihier-part:sym<authority> { "//" <iauthority> <ipath-abempty> }
        token ihier-part:sym<absolute> { <ipath-absolute> }
        token ihier-part:sym<rootless> { <ipath-rootless> }
        token ihier-part:sym<empty> { <ipath-empty> }
        token IRI-reference { [<TOP> | <irelative-ref>] }
        token absolute-IRI {
            [<scheme> || <.panic('Malformed scheme')>]
            [":" || <.panic('Missing : after scheme')>]
            <ihier-part>
            ["?" <iquery>]?
        }
        token irelative-ref {
            <irelative-part> ["?" <iquery>]? ["#" <ifragment>]?
        }
        proto token irelative-part {*}
        token irelative-part:sym<authority> { "//" <iauthority> <ipath-abempty> }
        token irelative-part:sym<absolute> { <ipath-absolute> }
        token irelative-part:sym<rootless> { <ipath-rootless> }
        token irelative-part:sym<empty> { <ipath-empty> }

        token iauthority {
            [<iuserinfo> "@"]?
            <ihost> [":" <port>]?
        }

        token iuserinfo {
            [<iunreserved> | <pct-encoded> | <sub-delims> | ':']*
        }

        proto token ihost {*}
        token ihost:sym<IPv4address> {
            <.IPv4address>
        }
        regex ihost:sym<IPv6address> {
            '[' <( <.IPv6address> )> ']'
        }
        token ihost:sym<IPvFuture> {
            '[' <(
            v <[A..Fa..f0..9]>+ '.'
            <[A..Za..z0..9!$&'()*+,;=:._~-]>+
            )> ']'
        }
        token ihost:sym<ireg-name> {
            {} [<iunreserved> | <pct-encoded> | <sub-delims>]*
        }

        token ipath-abempty { ["/" <isegment>]* }
        token ipath-absolute {
            "/" [<isegment-nz> ["/" <isegment>]*]?
        }
        token ipath-noscheme {
            <isegment-nz-nc> ["/" <isegment>]*
        }
        token ipath-rootless {
            <isegment-nz> ["/" <isegment>]*
        }
        token ipath-empty { '' }

        token ref {
            || <?before <.scheme> ':'> <IRI>
            || <relative-ref>
        }

        token relative-ref {
            <irelative-part> [ '?' <iquery>] ? [ '#' <ifragment> ]?
            [ $ || <.panic('unexpected text at end')> ]
        }

        token isegment { <ipchar>* }
        token isegment-nz { <ipchar>+ }
        token isegment-nz-nc { [<iunreserved> | <pct-encoded> | <sub-delims> | '@']+ }

        token ipchar { [<iunreserved> | <pct-encoded> | <sub-delims> | ':' | '@'] }
        token iquery { [<ipchar> | <iprivate> | '/' | '?']* }
        token ifragment { [<ipchar> | '/' | '?']* }
        token iunreserved { [<alnum> | '-' | '.' | '_' | '~' | <ucschar>] }
        token ucschar { <[\xA0..\xD7FF     \xF900..\xFDCF   \xFDF0..\xFFEF
                          \x10000..\x1FFFD \x20000..\x2FFFD \x30000..\x3FFFD
                          \x40000..\x4FFFD \x50000..\x5FFFD \x60000..\x6FFFD
                          \x70000..\x7FFFD \x80000..\x8FFFD \x90000..\x9FFFD
                          \xA0000..\xAFFFD \xB0000..\xBFFFD \xC0000..\xCFFFD
                          \xD0000..\xDFFFD \xE1000..\xEFFFD ]> }
        token iprivate { <[\xE000..\xF8FF \xF0000..\xFFFFD \x100000..\x10FFFD]> }
        token pct-encoded {
            '%' <xdigit> <xdigit>
        }
        token sub-delims { <[!$&'()*+,;=]> }

        method panic($reason) {
            die X::Cro::Iri::ParseError.new(iri-string => self.orig, :$reason)
        }
    }

    class GenericActions is Cro::Uri::GenericActions {
        method TOP($/) {
            make $<IRI>.ast;
        }

        method IRI($/) {
            my %parts = scheme => ~$<scheme>, |$<ihier-part>.ast;
            %parts<query> = $<iquery>.ast if $<iquery>;
            %parts<fragment> = $<ifragment>.ast if $<ifragment>;
            make Cro::Iri.bless(|%parts);
        }

        method ihier-part:sym<authority>($/) {
            make {
                path => $<ipath-abempty>.ast,
                $<iauthority>.ast
            }
        }

        method ihier-part:sym<absolute>($/) {
            make (path => $<ipath-absolute>.ast);
        }

        method ihier-part:sym<rootless>($/) {
            make (path => $<ipath-rootless>.ast);
        }

        method ihier-part:sym<empty>($/) {
            make (path => $<ipath-empty>.ast);
        }

        method iauthority($/) {
            make {
                authority => ~$/,
                port => $<port> ?? $<port>.ast !! Int,
                userinfo => $<iuserinfo> ?? ~$<iuserinfo> !! Str,
                $<ihost>.ast
            };
        }

        method ihost:sym<IPv4address>($/) {
            make {
                host => ~$/,
                host-class => Cro::ResourceIdentifier::Host::IPv4
            }
        }

        method ihost:sym<IPv6address>($/) {
            make {
                host => ~$/,
                host-class => Cro::ResourceIdentifier::Host::IPv6
            }
        }

        method ihost:sym<IPvFuture>($/) {
            make {
                host => ~$/,
                host-class => Cro::ResourceIdentifier::Host::IPvFuture
            }
        }

        method ihost:sym<ireg-name>($/) {
            make {
                host => decode-percents(~$/),
                host-class => Cro::ResourceIdentifier::Host::RegName
            }
        }

        method ipath-abempty($/) {
            make ~$/;
        }

        method ipath-absolute($/) {
            make ~$/;
        }

        method ipath-rootless($/) {
            make ~$/;
        }

        method ipath-empty($/) {
            make '';
        }

        method iquery($/) {
            make ~$/;
        }

        method ifragment($/) {
            make ~$/;
        }

        method ref($/) {
            make ($<IRI> // $<relative-ref>).ast
        }

        method relative-ref($/) {
            my %parts = $<irelative-part>.ast;
            %parts<query> = .ast with $<iquery>;
            %parts<fragment> = .ast with $<ifragment>;
            make Cro::Iri.bless(|%parts);
        }
    }

    method parse(Str() $iri-string, :$grammar = Cro::Iri::GenericParser,
                 :$actions = Cro::Iri::GenericActions.new --> Cro::Iri) {
        with $grammar.parse($iri-string, :$actions) {
            .ast
        } else {
            die X::Cro::Iri::ParseError.new(:$iri-string)
        }
    }

    sub encode-percents-except-ASCII(Str $s) {
        $s.subst: :g, /<-[A..Za..z0..9_.~:/%=-]>+/, {
            .Str.encode('utf8').list.map({ sprintf '%%%02s', .base(16) }).join
        }
    }

    method to-uri(--> Cro::Uri) {
        Cro::Uri.new(
            |(scheme => encode-percents-except-ASCII($_) with $!scheme),
            |(authority => encode-percents-except-ASCII($_) with $!authority),
            |(userinfo => encode-percents-except-ASCII($_) with $!userinfo),
            |(host => encode-percents-except-ASCII($_) with $!host),
            :$!host-class,
            :$!port,
            |(path => encode-percents-except-ASCII($_) with $!path),
            |(query => encode-percents-except-ASCII($_) with $!query),
            |(fragment => encode-percents-except-ASCII($_) with $!fragment),
        );
    }
}

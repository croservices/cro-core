class X::Cro::Uri::ParseError is Exception {
    has $.reason = 'malformed syntax';
    has $.uri-string is required;
    method message() {
        "Unable to parse URI '$!uri-string': $!reason"
    }
}

class Cro::Uri {
    enum Host <RegName IPv4 IPv6 IPvFuture>;

    has Str $.origin;
    has Str $.scheme;
    has Str $.authority;
    has Str $.userinfo;
    has Str $.host;
    has Host $.host-class;
    has Int $.port;
    has Str $.path;
    has Str $.query;
    has Str $.fragment;

    grammar GenericParser {
        token TOP {
            [ <scheme> || <.panic('Malformed scheme')> ]
            [ ":" || <.panic('Missing : after scheme')> ]
            <hier-part>
            [ "?" <query> ]?
            [ "#" <fragment> ]?
            [ $ || <.panic('unexpected text at end')> ]
        }

        token scheme {
            <[A..Za..z]> <[A..Za..z0..9+.-]>*
        }

        proto token hier-part { * }
        token hier-part:sym<authority> { "//" <authority> <path-abempty> }
        token hier-part:sym<absolute>  { <path-absolute> }
        token hier-part:sym<rootless>  { <path-rootless> }
        token hier-part:sym<empty>     { <path-empty> }

        token authority {
            [ <userinfo> "@" ]?
            <host> [ ":" <port> ]?
        }

        token userinfo {
            [ <[A..Za..z0..9!$&'()*+,;=._~:-]>+ | '%' <[A..Fa..f0..9]>**2 ]*
        }

        proto token host { * }
        token host:sym<IPv4address> {
            <.IPv4address>
        }
        regex host:sym<IPv6address> {
            '[' <( [
                ||                                         [ <.h16> ":" ] ** 6 <.ls32>
                ||                                    "::" [ <.h16> ":" ] ** 5 <.ls32>
                || [                        <.h16> ]? "::" [ <.h16> ":" ] ** 4 <.ls32>
                || [ [ <.h16> ":" ] ** 0..1 <.h16> ]? "::" [ <.h16> ":" ] ** 3 <.ls32>
                || [ [ <.h16> ":" ] ** 0..2 <.h16> ]? "::" [ <.h16> ":" ] ** 2 <.ls32>
                || [ [ <.h16> ":" ] ** 0..3 <.h16> ]? "::"   <.h16> ":"        <.ls32>
                || [ [ <.h16> ":" ] ** 0..4 <.h16> ]? "::"                     <.ls32>
                || [ [ <.h16> ":" ] ** 0..5 <.h16> ]? "::"                     <.h16>
                || [ [ <.h16> ":" ] ** 0..6 <.h16> ]? "::"
            ] )> ']'
        }
        token host:sym<IPvFuture> {
            '[' <(
            v <[A..Fa..f0..9]>+ '.'
            <[A..Za..z0..9!$&'()*+,;=:._~-]>+
            )> ']'
        }
        token host:sym<reg-name> {
            {} [ <[A..Za..z0..9!$&'()*+,;=._~-]>+ | '%' <[A..Fa..f0..9]>**2 ]*
        }

        token IPv4address {
            <.dec-octet> ** 4 % "." [<?[/#?:\]]> || $]
        }

        token dec-octet {
            | <[0..9]>
            | <[1..9]> <[0..9]>
            | "1" <[0..9]> <[0..9]>
            | "2" <[0..4]> <[0..9]>
            | "25" <[0..5]>
        }

        token ls32 {
            || <.h16> ":" <.h16>
            || <.IPv4address>
        }

        token h16 {
            <[A..Fa..f0..9]> ** 1..4
        }

        token port {
            \d*
        }

        token path-abempty {
            [ "/" <segment> ]*
        }

        token path-absolute {
            <!>
        }

        token path-rootless {
            <segment-nz> [ "/" <segment> ]*
        }

        token path-empty {
            ''
        }

        token segment {
            <.pchars>?
        }

        token segment-nz {
            <.pchars>
        }

        token query {
            [ <.pchars> | "/" | "?" ]*
        }

        token fragment {
            [ <.pchars> | "/" | "?" ]*
        }

        token pchars {
            [<[A..Za..z0..9._~:@!$&'()*+,;=-]>+ | '%' <[A..Fa..f0..9]>**2]+
        }

        method panic($reason) {
            die X::Cro::Uri::ParseError.new(uri-string => self.orig, :$reason)
        }
    }

    class GenericActions {
        method TOP($/) {
            my %parts = scheme => ~$<scheme>, |$<hier-part>.ast;
            %parts<query> = $<query>.ast if $<query>;
            %parts<fragment> = $<fragment>.ast if $<fragment>;
            %parts<origin> = ~$/;
            make Cro::Uri.bless(|%parts);
        }

        method hier-part:sym<authority>($/) {
            make {
                path => $<path-abempty>.ast,
                $<authority>.ast
            };
        }

        method hier-part:sym<absolute>($/) {
            make (path => $<path-absolute>.ast);
        }

        method hier-part:sym<rootless>($/) {
            make (path => $<path-rootless>.ast);
        }

        method hier-part:sym<empty>($/) {
            make (path => $<path-empty>.ast);
        }

        method authority($/) {
            make {
                authority => ~$/,
                port => $<port> ?? $<port>.ast !! Int,
                userinfo => $<userinfo> ?? ~$<userinfo> !! Str,
                $<host>.ast
            };
        }

        method host:sym<IPv4address>($/) {
            make {
                host => ~$/,
                host-class => Cro::Uri::Host::IPv4
            };
        }

        method host:sym<IPv6address>($/) {
            make {
                host => ~$/,
                host-class => Cro::Uri::Host::IPv6
            };
        }

        method host:sym<IPvFuture>($/) {
            make {
                host => ~$/,
                host-class => Cro::Uri::Host::IPvFuture
            };
        }

        method host:sym<reg-name>($/) {
            make {
                host => decode-percents(~$/),
                host-class => Cro::Uri::Host::RegName
            };
        }

        method port($/) {
            my $port = ~$/;
            make $port ?? +$port !! Int;
        }

        method path-abempty($/) {
            make ~$/;
        }

        method path-rootless($/) {
            make ~$/;
        }

        method path-empty($/) {
            make '';
        }

        method query($/) {
            make ~$/;
        }

        method fragment($/) {
            make ~$/;
        }
    }

    method parse(Str() $uri-string, :$grammar = Cro::Uri::GenericParser,
                 :$actions = Cro::Uri::GenericActions --> Cro::Uri) {
        with $grammar.parse($uri-string, :$actions) {
            .ast
        }
        else {
            die X::Cro::Uri::ParseError.new(:$uri-string)
        }
    }

    method user(--> Str) {
        with $!userinfo {
            decode-percents(.split(":", 2)[0])
        }
        else {
            Str
        }
    }

    method password(--> Str) {
        with $!userinfo {
            with .split(":", 2)[1] {
                return decode-percents($_);
            }
        }
        return Str;
    }

    method path-segments(Cro::Uri:D: --> List) {
        my $no-leader = $!path.starts-with('/') ?? $!path.substr(1) !! $!path;
        $no-leader.split('/').map(&decode-percents).list
    }

    multi method Str(Cro::Uri:D: --> Str) {
        $!origin
    }

}

sub decode-percents(Str $s) is export(:decode-percents) {
    $s.contains('%')
        ?? $s.subst(:g, /[ '%' (<[A..Fa..f0..9]>**2) ]+/,
            -> $perseq {
                Blob.new($perseq[0].map({ :16(.Str) })).decode('utf8')
            })
        !! $s
}

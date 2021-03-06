class X::Cro::Uri::ParseError is Exception {
    has $.reason = 'malformed syntax';
    has $.uri-string is required;
    method message() {
        "Unable to parse URI '$!uri-string': $!reason"
    }
}

#| An immutable representation of a URI
class Cro::Uri {
    #| The kind of host found in the URI (a domain name or some kind of IP address)
    enum Host <RegName IPv4 IPv6 IPvFuture>;

    #| Given the example "https://user@cro.services:44433/example/url?foo=bar&x=42#here",
    #| this would return "https"
    has Str $.scheme;

    #| Given the example "https://user@cro.services:44433/example/url?foo=bar&x=42#here",
    #| this would return "user@cro.services:44433"
    has Str $.authority;

    #| Given the example "https://user@cro.services:44433/example/url?foo=bar&x=42#here",
    #| this would return "user"
    has Str $.userinfo;

    #| Given the example "https://user@cro.services:44433/example/url?foo=bar&x=42#here",
    #| this would return "cro.services"
    has Str $.host;

    #| Given the example "https://user@cro.services:44433/example/url?foo=bar&x=42#here",
    #| this would return Cro::Uri::Host::RegName
    has Host $.host-class;

    #| Given the example "https://user@cro.services:44433/example/url?foo=bar&x=42#here",
    #| this would return 44433
    has $.port;

    #| Given the example "https://user@cro.services:44433/example/url?foo=bar&x=42#here",
    #| this would return "/example/url"
    has Str $.path;

    #| Given the example "https://user@cro.services:44433/example/url?foo=bar&x=42#here",
    #| this would return "foo=bar&x=42"
    has Str $.query;

    #| Given the example "https://user@cro.services:44433/example/url?foo=bar&x=42#here",
    #| this would return "here"
    has Str $.fragment;

    grammar GenericParser {
        token TOP {
            <URI>
        }

        token URI {
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
            '[' <( <.IPv6address> )> ']'
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

        regex IPv6address {
            [
                ||                                         [ <.h16> ":" ] ** 6 <.ls32>
                ||                                    "::" [ <.h16> ":" ] ** 5 <.ls32>
                || [                        <.h16> ]? "::" [ <.h16> ":" ] ** 4 <.ls32>
                || [ [ <.h16> ":" ] ** 0..1 <.h16> ]? "::" [ <.h16> ":" ] ** 3 <.ls32>
                || [ [ <.h16> ":" ] ** 0..2 <.h16> ]? "::" [ <.h16> ":" ] ** 2 <.ls32>
                || [ [ <.h16> ":" ] ** 0..3 <.h16> ]? "::"   <.h16> ":"        <.ls32>
                || [ [ <.h16> ":" ] ** 0..4 <.h16> ]? "::"                     <.ls32>
                || [ [ <.h16> ":" ] ** 0..5 <.h16> ]? "::"                     <.h16>
                || [ [ <.h16> ":" ] ** 0..6 <.h16> ]? "::"
            ]
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
            '/' [ <segment-nz> [ "/" <segment> ]* ]?
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

        token ref {
            || <?before <.scheme> ':'> <URI>
            || <relative-ref>
        }

        token relative-ref {
            <relative-part> [ '?' <query>] ? [ '#' <fragment> ]?
            [ $ || <.panic('unexpected text at end')> ]
        }

        token relative-part {
            | [ '//' <authority> <path-abempty> ]
            | <path-absolute>
            | <path-noscheme>
            | <path-empty>
        }

        token path-noscheme {
            <.segment-nz-nc> [ "/" <segment> ]*
        }

        token segment-nz-nc {
            [<[A..Za..z0..9._~@!$&'()*+,;=-]>+ | '%' <[A..Fa..f0..9]>**2]+
        }

        method panic($reason) {
            die X::Cro::Uri::ParseError.new(uri-string => self.orig, :$reason)
        }
    }

    class GenericActions {
        has $.create;

        method TOP($/) {
            make $<URI>.ast;
        }

        method URI($/) {
            my %parts = scheme => ~$<scheme>, |$<hier-part>.ast;
            %parts<query> = $<query>.ast if $<query>;
            %parts<fragment> = $<fragment>.ast if $<fragment>;
            make (self ?? $!create !! Cro::Uri).bless(|%parts);
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

        method path-absolute($/) {
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

        method ref($/) {
            make ($<URI> || $<relative-ref>).ast;
        }

        method relative-ref($/) {
            my %parts = $<relative-part>.ast;
            %parts<query> = $<query>.ast if $<query>;
            %parts<fragment> = $<fragment>.ast if $<fragment>;
            make (self ?? $!create !! Cro::Uri).bless(|%parts);
        }

        method relative-part($/) {
            make $<authority>
                ?? %( $<authority>.ast, path => $<path-abempty>.ast )
                !! %( path => ($<path-absolute> || $<path-noscheme> || $<path-empty>).ast );
        }

        method path-noscheme($/) {
            make ~$/;
        }
    }

    submethod TWEAK(:$authority, :$host) {
        if $authority && !$host.defined {
            # We were constructed with an unparsed authority.
            with GenericParser.parse($authority, :rule<authority>, :actions(GenericActions)) {
                given .ast {
                    $!host = $_ with .<host>;
                    $!host-class = $_ with .<host-class>;
                    $!port = $_ with .<port>;
                    $!userinfo = $_ with .<userinfo>;
                }
            }
        }
    }

    #| Parse a URI into a Cro::Uri object
    method parse(Str() $uri-string, :$grammar = Cro::Uri::GenericParser,
                 :$actions = Cro::Uri::GenericActions.new(create => self) --> Cro::Uri) {
        with $grammar.parse($uri-string, :$actions) {
            .ast
        }
        else {
            die X::Cro::Uri::ParseError.new(:$uri-string)
        }
    }

    #| Parse a URI reference (that is, either an absolute or relative URI) into
    #| a Cro::Uri object
    method parse-ref(Str() $uri-string, :$grammar = Cro::Uri::GenericParser,
                     :$actions = Cro::Uri::GenericActions.new(create => self) --> Cro::Uri) {
        with $grammar.parse($uri-string, :$actions, :rule<ref>) {
            .ast
        }
        else {
            die X::Cro::Uri::ParseError.new(:$uri-string)
        }
    }

    #| Parse a relative URI into a Cro::Uri object (a relative URI must not
    #| include a scheme)
    method parse-relative(Str() $uri-string, :$grammar = Cro::Uri::GenericParser,
                          :$actions = Cro::Uri::GenericActions.new(create => self) --> Cro::Uri) {
        with $grammar.parse($uri-string, :$actions, :rule<relative-ref>) {
            .ast
        }
        else {
            die X::Cro::Uri::ParseError.new(:$uri-string)
        }
    }

    #| Obtain the user part of the user info, if any, with percent sequences
    #| decoded
    method user(--> Str) {
        with $!userinfo {
            decode-percents(.split(":", 2)[0])
        }
        else {
            Str
        }
    }

    #| Obtain the password part of the user info, if any, with percent sequences
    #| decoded (use of this is considered deprecated)
    method password(--> Str) {
        with $!userinfo {
            with .split(":", 2)[1] {
                return decode-percents($_);
            }
        }
        return Str;
    }

    #| Return an array of path segments, decoding any percent sequences found in
    #| them. Given the example "https://user@cro.services:44433/example/url?foo=bar&x=42#here",
    #| this would return an array ["example", "foo"].
    method path-segments(Cro::Uri:D: --> List) {
        my $no-leader = $!path.starts-with('/') ?? $!path.substr(1) !! $!path;
        $no-leader.split('/').map(&decode-percents).list
    }

    #| Parse the string as a URI reference, and the apply the URI reference resolution
    #| algorithm to produce a new Cro::Uri. For example, if this was called on a
    #| Cro::Uri instance representing the URI "http://cro.serivces/docs", and the
    #| string passed contains "/roadmap", the result would be a Cro::Uri object
    #| representing "http://cro.services/roadmap".
    multi method add(Cro::Uri:D: Str:D $r --> Cro::Uri) {
        self.add(self.parse-ref($r))
    }

    #| Applies the URI reference resolution algorithm, treating the passed URI
    #| as a URI reference, in order to produce a new Cro::Uri. For example, if this was called on a
    #| Cro::Uri instance representing the URI "http://cro.serivces/docs", and the
    #| Cro::Uri instance passed as an argument represented "/roadmap", the result
    #| would be a Cro::Uri object representing "http://cro.services/roadmap".
    multi method add(Cro::Uri:D: Cro::Uri $r --> Cro::Uri) {
        my Str ($scheme, $authority, $path, $query);
        with $r.scheme {
            $scheme = $_;
            $authority = $r.authority;
            $path = remove-dot-segments($r.path);
            $query = $r.query;
        }
        else {
            with $r.authority {
                $authority = $_;
                $path = remove-dot-segments($r.path);
                $query = $r.query;
            }
            else {
                if $r.path eq '' {
                    $path = $!path;
                    with $r.query {
                        $query = $_;
                    }
                    else {
                        $query = $!query;
                    }
                }
                else {
                    if $r.path.starts-with('/') {
                        $path = remove-dot-segments($r.path);
                    }
                    else {
                        $path = remove-dot-segments(self!merge-path($r.path));
                    }
                    $query = $r.query;
                }
                $authority = $!authority;
            }
            $scheme = $!scheme;
        }
        self.new(:$scheme, :$authority, :$path, :$query, :fragment($r.fragment))
    }

    sub remove-dot-segments($path) {
        my $input = $path;
        my $output = '';
        while $input {
            if $input.starts-with('../') {
                $input .= substr(3);
            }
            elsif $input.starts-with('./') {
                $input .= substr(2);
            }
            elsif $input.starts-with('/./') {
                $input = $input.substr(2);
            }
            elsif $input eq '/.' {
                $input = '/';
            }
            elsif $input.starts-with('/../') {
                $input = $input.substr(3);
                with $output.rindex('/') {
                    $output = $output.substr(0, $_);
                }
            }
            elsif $input eq '/..' {
                $input = '/';
                with $output.rindex('/') {
                    $output = $output.substr(0, $_);
                }
            }
            elsif $input eq '.' | '..' {
                $input = '';
            }
            else {
                with $input.index('/', 1) {
                    $output ~= $input.substr(0, $_);
                    $input = $input.substr($_);
                }
                else {
                    $output ~= $input;
                    $input = '';
                }
            }
        }
        $output
    }

    method !merge-path($r-path) {
        if $!authority.defined && $!path eq '' {
            "/$r-path"
        }
        orwith $!path.rindex('/') {
            $!path.substr(0, $_ + 1) ~ $r-path
        }
        else {
            $r-path
        }
    }

    #| Turn the Cro::Uri object into a string representation of the URI
    multi method Str(Cro::Uri:D: --> Str) {
        my $result = '';
        with $!scheme {
            $result ~= "$_:";
        }
        with $!authority {
            $result ~= "//$_";
        }
        $result ~= $!path;
        with $!query {
            $result ~= "?$_";
        }
        with $!fragment {
            $result ~= "#$_";
        }
        return $result;
    }

    grammar URI-Template {
        token TOP { [<literal> | <expression>]* }
        token literal { [ <literal-part> | <ucschar> | <iprivate> | <pct-encoded> ]+ }
        token literal-part { <[\x21 \x23 \x24 \x26 \x28..\x3B \x3D \x3F..\x5B \x5D \x5F \x61..\x7A]> }
        token ucschar  { <[ \xA0..\xD7FF \xF900..\xFDCF \xFDF0..\xFFEF
                            \x10000..\x1FFFD \x20000..\x2FFFD \x30000..\x3FFFD
                            \x40000..\x4FFFD \x50000..\x5FFFD \x60000..\x6FFFD
                            \x70000..\x7FFFD \x80000..\x8FFFD \x90000..\x9FFFD
                            \xA0000..\xAFFFD \xB0000..\xBFFFD \xC0000..\xCFFFD
                            \xD0000..\xDFFFD \xE1000..\xEFFFD ]> }
        token iprivate { <[ \xE000..\xF8FF \xF0000..\xFFFFD \x100000..\x10FFFD ]> }
        token pct-encoded { '%' <xdigit> <xdigit> }
        token expression { '{' <operator>? <var-list> '}' }
        token operator { <op2> | <op3> | <op-reserve> }
        token op2 { <[+#]> }
        token op3 { <[./;?&]> }
        token op-reserve { <[=,!@|]> }
        token var-list { <varspec> [',' <varspec>]* }
        token varspec  { <varname> <modifier-level4>? }
        token varname  { <varchar> ['.' | <varchar>]* }
        token varchar  { <alnum> | '_' | <pct-encoded> }
        token modifier-level4 { <prefix> | '*' }
        token prefix { ':' <[\x31..\x39]> \d ** 0..3 }
    }
}

#| Perform percent sequence decoding according to the URI specification.
#| Anything outside of the ASCII range will be interpreted as UTF-8.
sub decode-percents(Str $s) is export(:decode-percents) {
    $s.contains('%')
        ?? $s.subst(:g, /[ '%' (<[A..Fa..f0..9]>**2) ]+/,
            -> $perseq {
                Blob.new($perseq[0].map({ :16(.Str) })).decode('utf8')
            })
        !! $s
}

#| Perform percent sequence encoding according to the URI specification.
#| Any characters outside of the ASCII range will be encoded as UTF-8,
#| and then each octet represented as a percent escape.
sub encode-percents(Str $s) is export(:encode-percents) {
    $s.subst: :g, /<-[A..Za..z0..9_.~-]>+/, {
        .Str.encode('utf8').list.map({ '%' ~ .base(16) }).join
    }
}

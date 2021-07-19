#| The kind of host found in the URI (a domain name or some kind of IP address)
enum Cro::ResourceIdentifier::Host <RegName IPv4 IPv6 IPvFuture>;

role Cro::ResourceIdentifier {
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
    has Cro::ResourceIdentifier::Host $.host-class;

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

    #| Return an array of path segments, decoding any percent sequences found in
    #| them. Given the example "https://user@cro.services:44433/example/url?foo=bar&x=42#here",
    #| this would return an array ["example", "foo"].
    method path-segments(Cro::ResourceIdentifier:D: --> List) {
        my $no-leader = $!path.starts-with('/') ?? $!path.substr(1) !! $!path;
        $no-leader.split('/').map(&decode-percents).list
    }
}

sub decode-percents(Str $s) {
    $s.contains('%')
            ?? $s.subst(:g, /[ '%' (<[A..Fa..f0..9]>**2) ]+/,
                    -> $perseq {
                        Blob.new($perseq[0].map({ :16(.Str) })).decode('utf8')
                    })
            !! $s
}
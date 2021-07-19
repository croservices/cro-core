use Cro::Iri;
use Cro::Uri;
use Test;

sub parses($desc, $uri, *@checks, :$relative, :$ref) {
    my $method = $relative ?? 'parse-relative' !!
            $ref      ?? 'parse-ref' !!
            'parse';
    with try Cro::Iri."$method"($uri) -> $parsed {
        pass $desc;
        for @checks.kv -> $i, $check {
            ok $check($parsed), "Check {$i + 1}";
        }
    }
    else {
        diag "URI parsing failed: $!";
        flunk $desc;
        skip 'Failed to parse', @checks.elems;
    }
}

sub refuses($desc, $uri) {
    with try Cro::Iri.parse($uri) {
        diag "Incorrectly parsed $uri";
        flunk $desc;
    }
    elsif $! ~~ X::Cro::Iri::ParseError {
        pass $desc;
    }
    else {
        diag "Wrong exception type ($!.^name())";
        flunk $desc;
    }
}
ok Cro::Iri::GenericParser.parse('urn:märz'), 'Simple IRI with Unicode parsed';

parses 'Simple URN',
        'urn:example:animal:ferret:nose',
        *.scheme eq 'urn',
        !*.authority.defined,
        *.path eq 'example:animal:ferret:nose',
        !*.query.defined,
        !*.fragment.defined;

parses 'Percent-encoded things in reg-name',
        'foo://%C3%80b.%E3%82%A2%E3%82%A2.com:8080/',
        *.scheme eq 'foo',
        *.authority eq '%C3%80b.%E3%82%A2%E3%82%A2.com:8080',
        *.host eq "\c[LATIN CAPITAL LETTER A WITH GRAVE]b.\c[KATAKANA LETTER A]\c[KATAKANA LETTER A].com",
        *.host-class == Cro::ResourceIdentifier::Host::RegName,
        *.port == 8080,
        !*.userinfo.defined,
        *.path eq '/';

# TODO userinfo
parses 'Percent-encoded things in reg-name',
        "foo://\c[LATIN CAPITAL LETTER A WITH GRAVE]b.\c[KATAKANA LETTER A]\c[KATAKANA LETTER A].com:8080/",
        *.scheme eq 'foo',
        *.authority eq "\c[LATIN CAPITAL LETTER A WITH GRAVE]b.\c[KATAKANA LETTER A]\c[KATAKANA LETTER A].com:8080",
        *.host eq "\c[LATIN CAPITAL LETTER A WITH GRAVE]b.\c[KATAKANA LETTER A]\c[KATAKANA LETTER A].com",
        *.host-class == Cro::ResourceIdentifier::Host::RegName,
        *.port == 8080,
        !*.userinfo.defined,
        *.path eq '/';

parses 'GH-27',
        'https://httpbin.org/get?q=تست',
        *.scheme eq 'https',
        *.authority eq "httpbin.org",
        *.host eq "httpbin.org",
        *.host-class == Cro::ResourceIdentifier::Host::RegName,
        !*.userinfo.defined,
        *.path eq '/get';

{
    my $uri = Cro::Iri.parse("foo://\c[LATIN CAPITAL LETTER A WITH GRAVE]b.\c[KATAKANA LETTER A]\c[KATAKANA LETTER A].com:8080/").to-uri;
    is $uri.scheme, 'foo';
    is $uri.authority, '%C3%80b.%E3%82%A2%E3%82%A2.com:8080';
    is $uri.host, '%C3%80b.%E3%82%A2%E3%82%A2.com';
    is $uri.host-class, Cro::ResourceIdentifier::Host::RegName;
    is $uri.port, 8080;
    ok !$uri.userinfo.defined;
    is $uri.path, '/';
}

refuses "Unicode in protocol", "Ÿ://foo";

done-testing;

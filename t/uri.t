use Crow::Uri;
use Test;

sub parses($desc, $uri, *@checks) {
    with try Crow::Uri.parse($uri) -> $parsed {
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
    with try Crow::Uri.parse($uri) {
        diag "Incorrectly parsed $uri";
        flunk $desc;
    }
    elsif $! ~~ X::Crow::Uri::ParseError {
        pass $desc;
    }
    else {
        diag "Wrong exception type ($!.^name())";
        flunk $desc;
    }
}

parses 'Simple URN',
    'urn:example:animal:ferret:nose',
    *.scheme eq 'urn',
    !*.authority.defined,
    *.path eq 'example:animal:ferret:nose',
    !*.query.defined,
    !*.fragment.defined;

parses 'URN with empty path',
    'wat:',
    *.scheme eq 'wat',
    !*.authority.defined,
    *.path eq '',
    !*.query.defined,
    !*.fragment.defined;

parses 'A URI with all component parts',
    'foo://example.com:8042/over/there?name=ferret#nose',
    *.scheme eq 'foo',
    *.authority eq 'example.com:8042',
    *.path eq '/over/there',
    *.query eq 'name=ferret',
    *.fragment eq 'nose';

parses 'A URI without a query or fragment',
    'foo://example.com:8042/over/there',
    *.scheme eq 'foo',
    *.authority eq 'example.com:8042',
    *.path eq '/over/there',
    !*.query.defined,
    !*.fragment.defined;

parses 'A URI with a query but no fragment',
    'foo://example.com:8042/over/there?name=ferret',
    *.scheme eq 'foo',
    *.authority eq 'example.com:8042',
    *.path eq '/over/there',
    *.query eq 'name=ferret',
    !*.fragment.defined;

parses 'A URI with a fragment but no query',
    'foo://example.com:8042/over/there#nose',
    *.scheme eq 'foo',
    *.authority eq 'example.com:8042',
    *.path eq '/over/there',
    !*.query.defined,
    *.fragment eq 'nose';

parses 'A URI with an empty path',
    'foo://example.com:8042',
    *.scheme eq 'foo',
    *.authority eq 'example.com:8042',
    *.path eq '',
    !*.query.defined,
    !*.fragment.defined;

parses 'A URI with a path of /',
    'foo://example.com:8042/',
    *.scheme eq 'foo',
    *.authority eq 'example.com:8042',
    *.path eq '/',
    !*.query.defined,
    !*.fragment.defined;

parses 'A URI with an empty path and a query',
    'foo://example.com:8042?name=ferret',
    *.scheme eq 'foo',
    *.authority eq 'example.com:8042',
    *.path eq '',
    *.query eq 'name=ferret',
    !*.fragment.defined;

parses 'A URI with an empty path and a fragment',
    'foo://example.com:8042#nose',
    *.scheme eq 'foo',
    *.authority eq 'example.com:8042',
    *.path eq '',
    !*.query.defined,
    *.fragment eq 'nose';

parses 'Empty query and fragment are defined and empty string',
    'foo://example.com:8042?#',
    *.scheme eq 'foo',
    *.authority eq 'example.com:8042',
    *.path eq '',
    *.query.defined,
    *.query eq '',
    *.fragment.defined,
    *.fragment eq '';

refuses 'Something without a : after a scheme', 'foo';

refuses 'Scheme starting with a digit', '1ab:example';
refuses 'Scheme starting with a +', '+ab:example';
refuses 'Scheme starting with a -', '-ab:example';
refuses 'Scheme starting with a .', '.ab:example';
refuses 'Scheme starting with a !', '!ab:example';
refuses 'Scheme starting with a ~', '~ab:example';
refuses 'Scheme starting with a /', '/ab:example';
refuses 'Scheme starting with a :', ':ab:example';

for <a a1 redis+tls some-protocol some.protocol LOUD-CAT x123+45.6-7z> -> $s {
    parses "URN with scheme $s",
        $s ~ ':example:animal:ferret:nose',
        *.scheme eq $s,
        !*.authority.defined,
        *.path eq 'example:animal:ferret:nose',
        !*.query.defined,
        !*.fragment.defined;
}

for qw/%% " ^ [ ] { } < >/ -> $bad {
    refuses $bad ~ ' in path', 'foo://localhost/bar/a' ~ $bad ~ '/wat';
}

parses 'Path broken up into segments',
    'foo://example.com/abc/d-e/fg',
    *.scheme eq 'foo',
    *.authority eq 'example.com',
    *.path eq '/abc/d-e/fg',
    *.path-segments.elems == 3,
    *.path-segments[0] eq 'abc',
    *.path-segments[1] eq 'd-e',
    *.path-segments[2] eq 'fg';

parses 'Simple percent escapes in path',
    'foo://example.com/a%20b/%2F%2Fc',
    *.scheme eq 'foo',
    *.authority eq 'example.com',
    *.path eq '/a%20b/%2F%2Fc',
    *.path-segments.elems == 2,
    *.path-segments[0] eq 'a b',
    *.path-segments[1] eq '//c';

parses 'UTF-8 escapes in path',
    'foo://example.com/%C3%80b/%E3%82%A2%E3%82%A2',
    *.scheme eq 'foo',
    *.authority eq 'example.com',
    *.path eq '/%C3%80b/%E3%82%A2%E3%82%A2',
    *.path-segments.elems == 2,
    *.path-segments[0] eq "\c[LATIN CAPITAL LETTER A WITH GRAVE]b",
    *.path-segments[1] eq "\c[KATAKANA LETTER A]\c[KATAKANA LETTER A]";

for qw[- . _ ~ : @ ! $ & ' ( ) * + , ; =] -> $ok {
    parses $ok ~ ' in path', 'foo://localhost/bar/a' ~ $ok ~ '/yes',
        *.scheme eq 'foo',
        *.authority eq 'localhost',
        *.path eq "/bar/a{$ok}/yes",
        !*.query.defined,
        !*.fragment.defined;
}

for qw/%% " ^ [ ] { } < >/ -> $bad {
    refuses $bad ~ ' in query', 'foo://localhost/bar?oh' ~ $bad ~ 'wat';
    refuses $bad ~ ' in fragment', 'foo://localhost/bar#oh' ~ $bad ~ 'wat';
}

for qw[- . _ ~ : @ ! $ & ' ( ) * + , ; = / ?] -> $ok {
    parses $ok ~ ' in query', 'foo://localhost/bar?oh' ~ $ok ~ 'yes',
        *.scheme eq 'foo',
        *.authority eq 'localhost',
        *.path eq '/bar',
        *.query eq "oh{$ok}yes",
        !*.fragment.defined;
    parses $ok ~ ' in fragment', 'foo://localhost/bar#oh' ~ $ok ~ 'yes',
        *.scheme eq 'foo',
        *.authority eq 'localhost',
        *.path eq '/bar',
        !*.query.defined,
        *.fragment eq "oh{$ok}yes";
}

done-testing;
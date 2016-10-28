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

done-testing;

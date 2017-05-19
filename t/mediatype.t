use Cro::MediaType;
use Test;

sub parses($media-type, $desc, &checks) {
    my $parsed;
    lives-ok { $parsed = Cro::MediaType.parse($media-type) }, $desc;
    checks($parsed) if $parsed;
}

sub refuses($media-type, $desc) {
    dies-ok { Cro::MediaType.parse($media-type) }, $desc;
}

parses 'text/plain', 'Simple text/plain media type', {
    is .type, 'text', 'Correct type';
    is .subtype, 'plain', 'Correct subtype';
    is .subtype-name, 'plain', 'Correct subtype name';
    is .tree, '', 'No tree';
    is .suffix, '', 'No suffix';
    is .parameters.elems, 0, 'No parameters';
    is .Str, 'text/plain', 'Stringifies correctly';
};

parses 'application/vnd.foobar+json', 'Vendor media type with suffix', {
    is .type, 'application', 'Correct type';
    is .subtype, 'vnd.foobar+json', 'Correct subtype';
    is .subtype-name, 'foobar', 'Correct subtype name';
    is .tree, 'vnd', 'Correct tree';
    is .suffix, 'json', 'Correct suffix';
    is .parameters.elems, 0, 'No parameters';
    is .Str, 'application/vnd.foobar+json', 'Stringifies correctly';
};

parses 'text/plain; charset=UTF-8', 'text/plain media type with charset', {
    is .type, 'text', 'Correct type';
    is .subtype, 'plain', 'Correct subtype';
    is .subtype-name, 'plain', 'Correct subtype name';
    is .tree, '', 'No tree';
    is .suffix, '', 'No suffix';
    is-deeply .parameters.List, ('charset' => 'UTF-8',), 'Correct parameter';
    is .Str, 'text/plain; charset=UTF-8', 'Stringifies correctly';
};

parses 'text/plain; charset="UTF-8"', 'text/plain media type with charset quoted', {
    is .type, 'text', 'Correct type';
    is .subtype, 'plain', 'Correct subtype';
    is .subtype-name, 'plain', 'Correct subtype name';
    is .tree, '', 'No tree';
    is .suffix, '', 'No suffix';
    is-deeply .parameters.List, ('charset' => 'UTF-8',), 'Correct parameter';
    is .Str, 'text/plain; charset=UTF-8', 'Stringifies correctly';
};

parses 'application/vnd.foobar; foo="bar\"d"; baz="\""', 'Parameters with escape', {
    is .type, 'application', 'Correct type';
    is .subtype, 'vnd.foobar', 'Correct subtype';
    is .subtype-name, 'foobar', 'Correct subtype name';
    is .tree, 'vnd', 'Correct tree';
    is .suffix, '', 'No suffix';
    is-deeply .parameters.List, ('foo' => 'bar"d', 'baz' => '"'),
        'Correct parameters';
    is .Str, 'application/vnd.foobar; foo="bar\"d"; baz="\""', 'Stringifies correctly';
};

refuses 'text', 'No /subtype';
refuses 'text', 'No subtype';
refuses 'x{y}/plain', 'Bad chars in type';
refuses 'text/z{d}', 'Bad chars in subtype';

done-testing;

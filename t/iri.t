use Cro::Iri;
use Test;

ok Cro::Iri::GenericParser.parse('urn:märz'), 'Simple IRI with Unicode parsed';

done-testing;

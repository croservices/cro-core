use Cro::Policy::Timeout;
use Test;

my $time-since-start = 0.5;
is Cro::Policy::Timeout[%( total => Inf, one => 1, two => 2 )].new(:total(10)).get-timeout($time-since-start, 'one'), 1,
    'Default timeout 1';
is Cro::Policy::Timeout[%( total => Inf, one => 1, two => 2 )].new(:total(10)).get-timeout($time-since-start, 'two'), 2,
    'Default timeout 2';

$time-since-start = 11.5;
is Cro::Policy::Timeout[%( total => Inf, one => 1, two => 2 )].new(:total(10)).get-timeout($time-since-start, 'one'), 0,
    'Timeout by total';

is Cro::Policy::Timeout[%( total => Inf, one => 1, two => 2 )].new(:total(Inf)).get-timeout($time-since-start, 'one'), 1,
    'No timeout by Inf total 1';
is Cro::Policy::Timeout[%( total => Inf, one => 1, two => 2 )].new(:total(Inf)).get-timeout($time-since-start, 'two'), 2,
    'No timeout by Inf total 2';

is Cro::Policy::Timeout[%( total => Inf, one => 1, two => 2 )].new(:total(Inf), two => 22).get-timeout($time-since-start, 'two'), 22,
    'Timeout by overridden phase';

done-testing;

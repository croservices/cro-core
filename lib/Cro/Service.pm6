role Cro::Service {
    has @.components is required;
    has Tap $!service-tap;

    method start(--> Nil) {
        $!service-tap = self!assemble-pipeline().tap: quit => { .note };
    }

    method !assemble-pipeline() {
        my @transforms = @!components;
        my $source = @transforms.shift;
        my $sink = @transforms.pop;
        my $current = $source.incoming;
        for @transforms {
            $current = .transformer($current);
        }
        return $sink.sinker($current);
    }

    method stop(--> Nil) {
        $!service-tap.close;
    }
}

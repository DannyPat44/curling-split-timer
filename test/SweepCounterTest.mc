import Toybox.Lang;
import Toybox.Test;

//! A second (25 samples) of brushing at `strokesPerSecond`, as milli-g on
//! the forearm axis: a square wave of +/- `swing` around 1 g of gravity
(:debug)
function brushing(strokesPerSecond as Number, swing as Number) as Array<Number> {
    var samples = new Array<Number>[25];
    var half = 25 / (strokesPerSecond * 2);
    for (var i = 0; i < 25; ++i) {
        samples[i] = 1000 + ((i / half) % 2 == 0 ? swing : -swing);
    }
    return samples;
}

(:test)
function sweepCounterCountsSteadyBrushing(logger as Logger) as Boolean {
    var counter = new SweepCounter(25);
    var strokes = 0;
    for (var second = 0; second < 5; ++second) {
        strokes += counter.add(brushing(4, 1500));
    }
    // About 4 strokes a second (the first swing only sets the baseline)
    Test.assert(strokes >= 17 && strokes <= 20);
    return true;
}

(:test)
function sweepCounterIgnoresGentleMovement(logger as Logger) as Boolean {
    var counter = new SweepCounter(25);
    var strokes = 0;
    for (var second = 0; second < 5; ++second) {
        // Walking or gesturing: well under the threshold
        strokes += counter.add(brushing(2, 400));
    }
    Test.assertEqual(strokes, 0);
    return true;
}

(:test)
function sweepCounterNeedsARunOfStrokes(logger as Logger) as Boolean {
    var counter = new SweepCounter(25);
    // Three hard swings, then stillness: a throw or a wave, not sweeping
    var samples = [1000, 2600, 1000, -600, 1000, 2600, 1000, -600, 1000, 2600, 1000, -600] as Array<Number>;
    var strokes = counter.add(samples);
    for (var second = 0; second < 2; ++second) {
        strokes += counter.add(brushing(1, 0));
    }
    Test.assertEqual(strokes, 0);
    // A steady run counts, its first strokes all at once
    var run = 0;
    for (var second = 0; second < 3; ++second) {
        run += counter.add(brushing(4, 1500));
    }
    Test.assert(run >= SweepCounter.RUN);
    return true;
}

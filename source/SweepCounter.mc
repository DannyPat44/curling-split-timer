import Toybox.Lang;

//! Counts brushing strokes from the watch's accelerometer, one axis (y, along
//! the forearm), in milli-g.
//!
//! Gravity and slow arm movement are taken out with a running average, which
//! leaves the back-and-forth of the brush. A stroke is one full swing: the
//! signal rising past +THRESHOLD after it last fell past -THRESHOLD. The gap
//! between the two thresholds keeps jitter around zero from counting.
//!
//! Sweeping is a quick, steady rhythm; walking, throwing and gesturing are
//! not. So strokes only count in a run of at least RUN of them, each within
//! MAX_GAP_MS of the one before. A run's first strokes are counted together
//! once it reaches RUN, then each one as it comes.
//!
//! Tuned on a recorded game of 8 ends (25 samples a second): 2,333 strokes,
//! each end within 4% of the earlier stroke counter's count. Neither was
//! checked against a hand count.
class SweepCounter {
    static const THRESHOLD = 1000;
    static const MAX_GAP_MS = 700;
    static const RUN = 4;
    // How quickly the running average follows the arm, per sample
    static const SMOOTHING = 0.1;

    private var _sampleMs as Number;
    // The running average (gravity and slow movement), or null before any samples
    private var _baseline as Float? = null;
    // Which side of the thresholds the signal was last on: 1 above, -1 below, 0 neither yet
    private var _side as Number = 0;
    // Time in ms, counted in samples
    private var _clock as Number = 0;
    // The run so far: strokes in it, and when the last one was
    private var _run as Number = 0;
    private var _lastStroke as Number = 0;

    //! @param samplesPerSecond how often the accelerometer is read
    function initialize(samplesPerSecond as Number) {
        _sampleMs = 1000 / (samplesPerSecond > 0 ? samplesPerSecond : 25);
    }

    //! Take the next samples, oldest first
    //! @return the strokes they add (a run's first RUN strokes come at once)
    function add(samples as Array<Number>) as Number {
        var strokes = 0;
        for (var i = 0; i < samples.size(); ++i) {
            _clock += _sampleMs;
            var sample = samples[i].toFloat();
            var baseline = _baseline;
            baseline = baseline == null ? sample : baseline + SMOOTHING * (sample - baseline);
            _baseline = baseline;
            var swing = sample - baseline;
            if (swing > THRESHOLD && _side <= 0) {
                if (_side < 0) {
                    strokes += stroke();
                }
                _side = 1;
            } else if (swing < -THRESHOLD && _side >= 0) {
                _side = -1;
            }
        }
        return strokes;
    }

    //! A full swing: part of the current run, or the start of a new one
    //! @return the strokes it adds to the count
    private function stroke() as Number {
        if (_run > 0 && _clock - _lastStroke > MAX_GAP_MS) {
            _run = 0;
        }
        _run++;
        _lastStroke = _clock;
        if (_run < RUN) {
            return 0;
        }
        return _run == RUN ? RUN : 1;
    }
}

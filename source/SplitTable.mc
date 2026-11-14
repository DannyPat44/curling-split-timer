import Toybox.Lang;
import Toybox.Math;

//! Predicts where a rock stops from its back-line-to-hog split, with one
//! number for the ice learned from every marked rock.
//!
//! The split is the rock's average speed over the 27 ft from the back line
//! to the hog line, so it leaves the hog at about 27 / split ft/s. On the
//! ice it slows at a steady rate `a` (friction), so from the hog it travels
//! v² / 2a = (27 / split)² / 2a. All of that is one ice constant over the
//! split squared:
//!
//!     distance past the near hog line = K / split²     (K = 27² / 2a)
//!
//! Fast (keen) ice has a big K. The far tee is 93 ft past the near hog
//! line, so a mark (split t, stopped at f ft past the tee) says
//! K = (93 + f) * t². The ice is the weighted median of the recent marks'
//! K, newest counting most, so the ice can drift through a game and a
//! single bad mark hardly moves it.
//!
//! Positions run from shortest to longest: hogged, weights 1-12 (guards,
//! then the house ring by ring from the top 12-foot to the back 12-foot),
//! then through to the hack, the boards and hit weight.
class SplitTable {
    static const POSITIONS = 15;
    static const HOGGED = 0;
    static const BUTTON = 8;
    static const BACK_8 = 10;
    static const BACK_12 = 11;
    static const THROUGH = 12;
    static const BOARDS = 13;
    static const HIT = 14;
    // Before the back 8 and back 12 were told apart there were 14 positions,
    // one "back of house" where they are now (see fromOldMarks)
    static const OLD_POSITIONS = 14;

    // Where each position stops, in feet past the far tee (negative is
    // short of it): hogged short of the hog line, the guards, the house's
    // rings (12-, 8- and 4-foot, the button, then back 4-, 8- and 12-foot,
    // the last inside the back line at 6), the back line to the hack (12),
    // the boards, and beyond
    static const POSITION_FEET = [-23, -19, -16, -13, -9, -6, -4, -2, 0, 2, 4, 5, 9, 14, 20];
    static const HOG_LINE_FEET = -21;
    static const BACK_LINE_FEET = 6;
    static const HACK_FEET = 12;
    // Past this a rock would have gone well through the boards: hit weight
    static const HIT_FEET = 17;
    // Near hog line to far tee
    static const HOG_TO_TEE = 93.0;

    // Before any marks: a 3.70 s split stops on the button
    static const DEFAULT_BUTTON_SPLIT = 3700;
    static const DEFAULT_ICE = HOG_TO_TEE * 3.7 * 3.7;
    // Marks kept, and how much less each older one counts
    static const MAX_MARKS = 20;
    static const DECAY = 0.85;

    // Who threw a mark's rock (see Game.thrower), or UNKNOWN for marks saved
    // before throwers were kept
    static const UNKNOWN = -1;

    // Recent marks, oldest first: [split ms, position, thrower]
    private var _marks as Array<Array<Number> >;
    // The ice constant K, in ft·s²
    private var _ice as Float = DEFAULT_ICE;

    //! @param marks marks saved from an earlier game (see marks()), or null.
    //!     Marks saved before the back 8 and back 12 go through
    //!     fromOldMarks() first.
    function initialize(marks) {
        _marks = [] as Array<Array<Number> >;
        if (marks instanceof Array) {
            for (var i = 0; i < marks.size(); ++i) {
                var mark = marks[i];
                if (mark instanceof Array && (mark.size() == 2 || mark.size() == 3)
                        && mark[0] instanceof Number && mark[1] instanceof Number && informs(mark[1])) {
                    var thrower = mark.size() == 3 && mark[2] instanceof Number ? mark[2] : UNKNOWN;
                    _marks.add([mark[0], mark[1], thrower] as Array<Number>);
                }
            }
        }
        fit();
    }

    //! A position from before the back 8 and back 12 were told apart: the
    //! old "back of house" is the back 12-foot (both 5 ft past the tee), so
    //! it and the positions past it move up one, and the ice is unchanged
    static function fromOldPosition(position as Number) as Number {
        return position < BACK_8 ? position : position + 1;
    }

    //! Marks saved before the back 8 and back 12, in today's positions:
    //! a list of [split, position], or the even older table of 14 splits,
    //! one per position. Anything else gives no marks.
    static function fromOldMarks(old) as Array<Array<Number> > {
        var marks = [] as Array<Array<Number> >;
        if (!(old instanceof Array)) {
            return marks;
        }
        if (old.size() == OLD_POSITIONS && old[0] instanceof Number) {
            // Old positions 1 (a guard) to 11 (through) say how far it went
            for (var i = 1; i <= 11; ++i) {
                if (old[i] instanceof Number && old[i] > 0) {
                    marks.add([old[i], fromOldPosition(i)] as Array<Number>);
                }
            }
            return marks;
        }
        for (var i = 0; i < old.size(); ++i) {
            var mark = old[i];
            if (mark instanceof Array && mark.size() == 2 && mark[0] instanceof Number
                    && mark[1] instanceof Number) {
                marks.add([mark[0], fromOldPosition(mark[1])] as Array<Number>);
            }
        }
        return marks;
    }

    //! The position a rock with this split should stop at
    function estimate(split as Number) as Number {
        return positionAt(feetFor(split, _ice));
    }

    //! Where a rock with this split stops, in feet past the far tee
    function feet(split as Number) as Float {
        return feetFor(split, _ice);
    }

    //! The split (ms) that stops at a position on this ice
    function splitTime(position as Number) as Number {
        return splitFor(position, _ice);
    }

    //! The split (ms) that stops at a position before any marks
    function defaultSplit(position as Number) as Number {
        return splitFor(position, DEFAULT_ICE);
    }

    //! The ice constant K (ft·s²): bigger is faster ice
    function ice() as Float {
        return _ice;
    }

    //! The marks, oldest first; save these to remember the ice
    function marks() as Array<Array<Number> > {
        return _marks;
    }

    //! Record that a rock timed at `split` stopped at `position`, thrown by
    //! `thrower` (see Game.thrower). Hogged, board and hit rocks say only
    //! that the rock was short or long, not how far it went, so they don't
    //! change the ice.
    function mark(split as Number, position as Number, thrower as Number) as Void {
        if (split <= 0 || !informs(position)) {
            return;
        }
        _marks.add([split, position, thrower] as Array<Number>);
        if (_marks.size() > MAX_MARKS) {
            _marks = _marks.slice(_marks.size() - MAX_MARKS, null);
        }
        fit();
    }

    //! Forget all marks and go back to the starting ice
    function reset() as Void {
        _marks = [] as Array<Array<Number> >;
        fit();
    }

    //! Forget one thrower's marks (UNKNOWN: those from before throwers were
    //! kept); the ice is learned again from the rest
    function forget(thrower as Number) as Void {
        var kept = [] as Array<Array<Number> >;
        for (var i = 0; i < _marks.size(); ++i) {
            if (_marks[i][2] != thrower) {
                kept.add(_marks[i]);
            }
        }
        _marks = kept;
        fit();
    }

    //! Who the marks came from: [thrower, marks] for each, in order of
    //! thrower, UNKNOWN last
    function throwers() as Array<Array<Number> > {
        var found = [] as Array<Array<Number> >;
        for (var i = 0; i < _marks.size(); ++i) {
            var thrower = _marks[i][2];
            var j = 0;
            while (j < found.size() && found[j][0] != thrower) {
                j++;
            }
            if (j < found.size()) {
                found[j][1] += 1;
            } else {
                found.add([thrower, 1] as Array<Number>);
            }
        }
        // Insertion sort by thrower (a handful at most), UNKNOWN last
        for (var i = 1; i < found.size(); ++i) {
            var entry = found[i];
            var j = i - 1;
            while (j >= 0 && throwerOrder(found[j][0]) > throwerOrder(entry[0])) {
                found[j + 1] = found[j];
                j--;
            }
            found[j + 1] = entry;
        }
        return found;
    }

    private function throwerOrder(thrower as Number) as Number {
        return thrower == UNKNOWN ? 1000 : thrower;
    }

    //! Positions that say how far a rock went
    private function informs(position as Number) as Boolean {
        return position > HOGGED && position <= THROUGH;
    }

    //! The ice as the weighted median of each mark's K, the newest mark
    //! weighing 1, the one before DECAY, then DECAY², ...
    private function fit() as Void {
        var count = _marks.size();
        if (count == 0) {
            _ice = DEFAULT_ICE;
            return;
        }
        var ks = new Array<Float>[count];
        var weights = new Array<Float>[count];
        var total = 0.0;
        for (var i = 0; i < count; ++i) {
            var t = _marks[i][0] / 1000.0;
            ks[i] = (HOG_TO_TEE + (POSITION_FEET[_marks[i][1]] as Number)) * t * t;
            weights[i] = Math.pow(DECAY, count - 1 - i).toFloat();
            total += weights[i];
        }
        // Sort by K (insertion sort: at most MAX_MARKS)
        for (var i = 1; i < count; ++i) {
            var k = ks[i];
            var w = weights[i];
            var j = i - 1;
            while (j >= 0 && ks[j] > k) {
                ks[j + 1] = ks[j];
                weights[j + 1] = weights[j];
                j--;
            }
            ks[j + 1] = k;
            weights[j + 1] = w;
        }
        // The K where half the weight lies below
        var below = 0.0;
        for (var i = 0; i < count; ++i) {
            below += weights[i];
            if (below >= total / 2) {
                _ice = ks[i];
                return;
            }
        }
        _ice = ks[count - 1];
    }

    private function feetFor(split as Number, ice as Float) as Float {
        if (split <= 0) {
            return HIT_FEET + 1.0;
        }
        var t = split / 1000.0;
        return (ice / (t * t) - HOG_TO_TEE).toFloat();
    }

    private function splitFor(position as Number, ice as Float) as Number {
        var feet = position == HOGGED ? HOG_LINE_FEET : (position == HIT ? HIT_FEET : POSITION_FEET[position] as Number);
        return (Math.sqrt(ice / (HOG_TO_TEE + feet)) * 1000 + 0.5).toNumber();
    }

    //! The position a rock stopping `feet` past the tee ends up in: the
    //! nearest of weights 1-12 inside the back line, otherwise by line
    static function positionAt(feet as Float) as Number {
        if (feet < HOG_LINE_FEET) {
            return HOGGED;
        } else if (feet > HIT_FEET) {
            return HIT;
        } else if (feet > HACK_FEET) {
            return BOARDS;
        } else if (feet > BACK_LINE_FEET) {
            return THROUGH;
        }
        var best = 1;
        for (var i = 2; i < THROUGH; ++i) {
            var gap = (feet - (POSITION_FEET[i] as Number)).abs();
            if (gap < (feet - (POSITION_FEET[best] as Number)).abs()) {
                best = i;
            }
        }
        return best;
    }
}

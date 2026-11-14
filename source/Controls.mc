import Toybox.Lang;

//! What each button does during a game, by what the timer is doing. Kept
//! apart from the watch's input so it can be tested.
//!
//! Start is a plain stopwatch: timing a rock never logs it, so any rock
//! (ours or theirs) can be timed. Up on a split starts placing it to log.
//!
//! | Button      | Ready              | Timing           | Placing a rock    |
//! |-------------|--------------------|------------------|-------------------|
//! | Start       | start the timer    | stop it          | log it            |
//! | Back        | pause (menu)       | cancel the timer | stop placing      |
//! | Up          | place split to log | -                | move it shorter   |
//! | Down        | team list          | -                | move it deeper    |
//! | Hold Up     | hit (untimed)      | cancel, hit      | log it, then hit  |
//! | Hold screen | place split to log | -                | -                 |
module Controls {
    const READY = 0;
    const TIMING = 1;
    const PLACING = 2;

    //! @param state READY, TIMING or PLACING
    //! @param key :start, :back, :up, :down, :holdUp or :holdScreen
    //! @return the action, or :none
    function action(state as Number, key as Symbol) as Symbol {
        if (state == TIMING) {
            if (key == :start) {
                return :stopTimer;
            } else if (key == :back) {
                return :cancelTimer;
            } else if (key == :holdUp) {
                return :cancelAndHit;
            }
        } else if (state == PLACING) {
            if (key == :start) {
                return :log;
            } else if (key == :back) {
                return :unplace;
            } else if (key == :up) {
                return :shorter;
            } else if (key == :down) {
                return :deeper;
            } else if (key == :holdUp) {
                return :logAndHit;
            }
        } else {
            if (key == :start) {
                return :startTimer;
            } else if (key == :back) {
                return :pause;
            } else if (key == :up || key == :holdScreen) {
                return :place;
            } else if (key == :down) {
                return :stats;
            } else if (key == :holdUp) {
                return :hit;
            }
        }
        return :none;
    }
}

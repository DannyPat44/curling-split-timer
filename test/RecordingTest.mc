import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

//! Records and saves a real activity through GameSession, the way a game
//! ends on the watch. The activity file it writes is checked by
//! tools/check_test_activity.py (run by `make test`): every game field must
//! be in the summary and the last lap. They once weren't, because the
//! Fields were let go before the session was saved.
//!
//! The game: fours, the wearer at lead (one shot made); the second's
//! rocks timed at 3.70 and 3.80 in end 1 (scored 1-0) and 3.90 in end 2;
//! final score 5-3.
(:test)
function recordingSavesEveryGameField(logger as Logger) as Boolean {
    // The game is saved into the watch's own history: keep it as it was
    var accuracy = Application.Storage.getValue("myShotsMade");
    var process = new GameSession();
    process.setMyPosition(0);
    var game = process.getGame();
    game.start(Game.FOURS);
    process.onStart();
    // Only one activity records at a time
    Test.assertMessage(process.isSessionRecording(),
        "No activity: is a game still recording in the simulator? Run make test again");
    // The simulator only writes an activity that has run for a moment
    wait(2500);

    game.logRock(3700, SplitTable.BUTTON);
    game.logRock(3800, SplitTable.BUTTON);
    process.markMine(0, Game.MADE);
    Test.assert(process.completeEnd(1));
    // Each end is a lap, and the simulator drops one that took no time
    wait(1500);
    game.logRock(3900, SplitTable.BUTTON);
    process.setFinalScore(5, 3);
    process.onStop();
    process.resetSession(true);
    // ...and needs a moment to write it before the test run ends
    wait(2500);

    Test.assert(!process.isSessionActive());
    if (accuracy != null) {
        Application.Storage.setValue("myShotsMade", accuracy);
    } else {
        Application.Storage.deleteValue("myShotsMade");
    }
    return true;
}

(:debug)
function wait(ms as Number) as Void {
    var until = System.getTimer() + ms;
    while (System.getTimer() < until) {
    }
}

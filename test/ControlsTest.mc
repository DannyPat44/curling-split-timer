import Toybox.Lang;
import Toybox.Test;

(:test)
function controlsStartIsAPlainStopwatch(logger as Logger) as Boolean {
    // Timing never logs, so a split left alone doesn't stop the next timing
    Test.assertEqual(Controls.action(Controls.READY, :start), :startTimer);
    Test.assertEqual(Controls.action(Controls.TIMING, :start), :stopTimer);
    return true;
}

(:test)
function controlsLoggingIsUpThenStart(logger as Logger) as Boolean {
    Test.assertEqual(Controls.action(Controls.READY, :up), :place);
    Test.assertEqual(Controls.action(Controls.PLACING, :start), :log);
    Test.assertEqual(Controls.action(Controls.PLACING, :back), :unplace);
    return true;
}

(:test)
function controlsBackUndoesTheTimerFirst(logger as Logger) as Boolean {
    Test.assertEqual(Controls.action(Controls.TIMING, :back), :cancelTimer);
    Test.assertEqual(Controls.action(Controls.READY, :back), :pause);
    return true;
}

(:test)
function controlsUpAndDownMoveARockOnTheSheet(logger as Logger) as Boolean {
    // Up toward the hog line, Down toward the back of the sheet
    Test.assertEqual(Controls.action(Controls.PLACING, :up), :shorter);
    Test.assertEqual(Controls.action(Controls.PLACING, :down), :deeper);
    Test.assertEqual(Controls.action(Controls.READY, :down), :stats);
    Test.assertEqual(Controls.action(Controls.READY, :up), :place);
    // Nothing to move while timing
    Test.assertEqual(Controls.action(Controls.TIMING, :up), :none);
    Test.assertEqual(Controls.action(Controls.TIMING, :down), :none);
    return true;
}

(:test)
function controlsHoldUpIsAHitFromAnywhere(logger as Logger) as Boolean {
    Test.assertEqual(Controls.action(Controls.READY, :holdUp), :hit);
    Test.assertEqual(Controls.action(Controls.TIMING, :holdUp), :cancelAndHit);
    Test.assertEqual(Controls.action(Controls.PLACING, :holdUp), :logAndHit);
    return true;
}

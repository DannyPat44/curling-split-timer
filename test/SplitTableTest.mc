import Toybox.Lang;
import Toybox.Test;

(:debug)
function markTimes(table as SplitTable, split as Number, position as Number, times as Number) as Void {
    for (var i = 0; i < times; ++i) {
        table.mark(split, position, 0);
    }
}

(:test)
function splitTableDefaultsPutA370OnTheButton(logger as Logger) as Boolean {
    var table = new SplitTable(null);
    Test.assertEqual(table.estimate(3700), SplitTable.BUTTON);
    Test.assertEqual(table.splitTime(SplitTable.BUTTON), 3700);
    // 3.85 s goes about 86 ft past the hog: 7 ft short, nearest Top 12-foot
    Test.assertEqual(table.estimate(3850), 5);
    Test.assertEqual(table.estimate(3800), 6);
    Test.assertEqual(table.estimate(5000), SplitTable.HOGGED);
    Test.assertEqual(table.estimate(3000), SplitTable.HIT);
    return true;
}

(:test)
function splitTableSlowerSplitsStopShorter(logger as Logger) as Boolean {
    var table = new SplitTable(null);
    var last = SplitTable.HIT;
    for (var split = 3000; split <= 5000; split += 50) {
        var position = table.estimate(split);
        Test.assert(position <= last);
        last = position;
    }
    return true;
}

(:test)
function splitTableOneMarkSetsTheIce(logger as Logger) as Boolean {
    var table = new SplitTable(null);
    table.mark(3850, SplitTable.BUTTON, 0);
    Test.assertEqual(table.splitTime(SplitTable.BUTTON), 3850);
    Test.assertEqual(table.estimate(3850), SplitTable.BUTTON);
    // The whole sheet moves with it: slower ice needs slower splits everywhere
    Test.assert(table.splitTime(5) > table.defaultSplit(5));
    return true;
}

(:test)
function splitTableOneBadMarkHardlyMovesTheIce(logger as Logger) as Boolean {
    var table = new SplitTable(null);
    markTimes(table, 3800, SplitTable.BUTTON, 3);
    // Marked on the button with a takeout's split: a mistake
    table.mark(3500, SplitTable.BUTTON, 0);
    Test.assertEqual(table.splitTime(SplitTable.BUTTON), 3800);
    return true;
}

(:test)
function splitTableFollowsTheIceAsItChanges(logger as Logger) as Boolean {
    var table = new SplitTable(null);
    markTimes(table, 3800, SplitTable.BUTTON, 2);
    markTimes(table, 3900, SplitTable.BUTTON, 3);
    Test.assertEqual(table.splitTime(SplitTable.BUTTON), 3900);
    return true;
}

(:test)
function splitTableIgnoresHoggedBoardAndHitMarks(logger as Logger) as Boolean {
    var table = new SplitTable(null);
    table.mark(4500, SplitTable.HOGGED, 0);
    table.mark(3300, SplitTable.BOARDS, 0);
    table.mark(2800, SplitTable.HIT, 0);
    table.mark(0, SplitTable.BUTTON, 0);
    Test.assertEqual(table.marks().size(), 0);
    Test.assertEqual(table.splitTime(SplitTable.BUTTON), 3700);
    return true;
}

(:test)
function splitTableKeepsTheLastTwentyMarks(logger as Logger) as Boolean {
    var table = new SplitTable(null);
    markTimes(table, 3800, 7, 25);
    Test.assertEqual(table.marks().size(), SplitTable.MAX_MARKS);
    return true;
}

(:test)
function splitTableRestoresSavedMarks(logger as Logger) as Boolean {
    var table = new SplitTable(null);
    table.mark(3900, 6, 0);
    table.mark(3750, 9, 0);
    var restored = new SplitTable(table.marks());
    Test.assertEqual(restored.marks().size(), 2);
    Test.assertEqual(restored.splitTime(SplitTable.BUTTON), table.splitTime(SplitTable.BUTTON));
    return true;
}

(:test)
function splitTableReadsTheOldTableOfSplits(logger as Logger) as Boolean {
    var old = [-1, -1, -1, -1, -1, -1, -1, -1, 3850, -1, -1, -1, -1, 3000];
    var table = new SplitTable(SplitTable.fromOldMarks(old));
    // The button mark carries over; the hit mark says nothing about distance
    Test.assertEqual(table.marks().size(), 1);
    Test.assertEqual(table.splitTime(SplitTable.BUTTON), 3850);
    return true;
}

(:test)
function splitTableResetGoesBackToDefaults(logger as Logger) as Boolean {
    var table = new SplitTable(null);
    table.mark(4000, SplitTable.BUTTON, 0);
    table.reset();
    Test.assertEqual(table.marks().size(), 0);
    Test.assertEqual(table.splitTime(SplitTable.BUTTON), 3700);
    return true;
}

(:test)
function splitTablePositionsByLine(logger as Logger) as Boolean {
    Test.assertEqual(SplitTable.positionAt(-22.0), SplitTable.HOGGED);
    Test.assertEqual(SplitTable.positionAt(-20.0), 1);
    Test.assertEqual(SplitTable.positionAt(0.4), SplitTable.BUTTON);
    Test.assertEqual(SplitTable.positionAt(3.5), SplitTable.BACK_8);
    Test.assertEqual(SplitTable.positionAt(5.5), SplitTable.BACK_12);
    Test.assertEqual(SplitTable.positionAt(7.0), SplitTable.THROUGH);
    Test.assertEqual(SplitTable.positionAt(13.0), SplitTable.BOARDS);
    Test.assertEqual(SplitTable.positionAt(18.0), SplitTable.HIT);
    return true;
}

(:test)
function splitTableHasEveryRingFrontAndBack(logger as Logger) as Boolean {
    // Top 12-, 8- and 4-foot, the button, then back 4-, 8- and 12-foot,
    // deeper ring by ring and all inside the back line
    for (var position = SplitTable.BUTTON - 3; position < SplitTable.BACK_12; ++position) {
        Test.assert((SplitTable.POSITION_FEET[position] as Number) < (SplitTable.POSITION_FEET[position + 1] as Number));
    }
    Test.assert((SplitTable.POSITION_FEET[SplitTable.BACK_12] as Number) < SplitTable.BACK_LINE_FEET);
    Test.assertEqual(Labels.STOP_POSITIONS.size(), SplitTable.POSITIONS);
    Test.assertEqual(SplitTable.POSITION_FEET.size(), SplitTable.POSITIONS);
    Test.assertEqual(Labels.STOP_POSITIONS[SplitTable.BACK_8], "Back 8-foot");
    Test.assertEqual(Labels.STOP_POSITIONS[SplitTable.BACK_12], "Back 12-foot");
    return true;
}

(:test)
function splitTableMovesOldMarksToTodaysPositions(logger as Logger) as Boolean {
    // Old positions: 9 back 4-foot, 10 back of house, 11 through, 13 hit
    Test.assertEqual(SplitTable.fromOldPosition(9), 9);
    Test.assertEqual(SplitTable.fromOldPosition(10), SplitTable.BACK_12);
    Test.assertEqual(SplitTable.fromOldPosition(11), SplitTable.THROUGH);
    Test.assertEqual(SplitTable.fromOldPosition(13), SplitTable.HIT);
    var marks = SplitTable.fromOldMarks([[3700, 8], [3600, 10], [3400, 11]]);
    Test.assertEqual(marks.size(), 3);
    Test.assertEqual(marks[1][1], SplitTable.BACK_12);
    Test.assertEqual(marks[2][1], SplitTable.THROUGH);
    // The back of house and the back 12-foot are the same spot: the ice
    // they make is unchanged
    Test.assertEqual(SplitTable.POSITION_FEET[SplitTable.BACK_12], 5);
    var table = new SplitTable(marks);
    Test.assertEqual(table.marks().size(), 3);
    Test.assertEqual(SplitTable.fromOldMarks("junk").size(), 0);
    return true;
}

(:test)
function splitTableTellsTheBack8FromTheBack12(logger as Logger) as Boolean {
    var table = new SplitTable(null);
    // On the starting ice a 3.70 is the button; a little faster goes deeper
    Test.assertEqual(table.estimate(table.splitTime(SplitTable.BACK_8)), SplitTable.BACK_8);
    Test.assertEqual(table.estimate(table.splitTime(SplitTable.BACK_12)), SplitTable.BACK_12);
    Test.assert(table.splitTime(SplitTable.BACK_12) < table.splitTime(SplitTable.BACK_8));
    return true;
}

(:test)
function splitTableForgetsOneThrowersMarks(logger as Logger) as Boolean {
    var table = new SplitTable(null);
    // The lead's draws say fast ice; the vice's say slow
    markTimes(table, 4000, SplitTable.BUTTON, 3);
    for (var i = 0; i < 4; ++i) {
        table.mark(3500, SplitTable.BUTTON, 2);
    }
    var throwers = table.throwers();
    Test.assertEqual(throwers.size(), 2);
    Test.assertEqual(throwers[0][0], 0);
    Test.assertEqual(throwers[0][1], 3);
    Test.assertEqual(throwers[1][0], 2);
    Test.assertEqual(throwers[1][1], 4);
    Test.assertEqual(table.splitTime(SplitTable.BUTTON), 3500);
    // Forget the vice's: the ice is the lead's alone
    table.forget(2);
    Test.assertEqual(table.marks().size(), 3);
    Test.assertEqual(table.throwers().size(), 1);
    Test.assertEqual(table.splitTime(SplitTable.BUTTON), 4000);
    // Saved and read back, the throwers are kept
    var restored = new SplitTable(table.marks());
    Test.assertEqual(restored.throwers()[0][0], 0);
    return true;
}

(:test)
function splitTableMarksFromBeforeThrowersAreUnknown(logger as Logger) as Boolean {
    // Saved before throwers were kept: [split, position]
    var table = new SplitTable([[3700, SplitTable.BUTTON], [3750, SplitTable.BUTTON]]);
    table.mark(3800, SplitTable.BUTTON, Game.DOUBLES_THROWERS + Game.PARTNER);
    var throwers = table.throwers();
    Test.assertEqual(throwers.size(), 2);
    // Known throwers first, the unknown last
    Test.assertEqual(throwers[0][0], Game.DOUBLES_THROWERS + Game.PARTNER);
    Test.assertEqual(throwers[1][0], SplitTable.UNKNOWN);
    Test.assertEqual(throwers[1][1], 2);
    Test.assertEqual(Labels.thrower(SplitTable.UNKNOWN), "Earlier marks");
    Test.assertEqual(Labels.thrower(Game.DOUBLES_THROWERS + Game.PARTNER), "Partner (doubles)");
    Test.assertEqual(Labels.thrower(1), "Second");
    table.forget(SplitTable.UNKNOWN);
    Test.assertEqual(table.marks().size(), 1);
    return true;
}

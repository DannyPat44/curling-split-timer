import Toybox.Lang;
import Toybox.Test;

(:debug)
function logRocks(game as Game, count as Number) as Symbol {
    var outcome = :rock;
    for (var i = 0; i < count; ++i) {
        outcome = game.logRock(3700 + i, SplitTable.BUTTON);
    }
    return outcome;
}

(:test)
function gameStartsOnEndOneWithTheLead(logger as Logger) as Boolean {
    var game = new Game();
    Test.assertEqual(game.end(), 0);
    game.start(Game.FOURS);
    Test.assertEqual(game.end(), 1);
    Test.assertEqual(game.rocks(), 0);
    Test.assertEqual(game.nextPlayer(), 0);
    return true;
}

(:test)
function gameRotatesPlayersTwoRocksEach(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    logRocks(game, 2);
    Test.assertEqual(game.nextPlayer(), 1);
    logRocks(game, 5);
    Test.assertEqual(game.nextPlayer(), 3);
    logRocks(game, 1);
    // End complete: still shows the skip rather than running off the end
    Test.assertEqual(game.nextPlayer(), 3);
    return true;
}

(:test)
function gameEighthRockCompletesTheEnd(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    Test.assertEqual(logRocks(game, 7), :rock);
    Test.assertEqual(logRocks(game, 1), :endComplete);
    Test.assert(game.nextEnd());
    Test.assertEqual(game.end(), 2);
    Test.assertEqual(game.rocks(), 0);
    return true;
}

(:test)
function gameEndsAfterEightEnds(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    for (var end = 1; end < Game.ENDS; ++end) {
        logRocks(game, 8);
        game.nextEnd();
    }
    Test.assertEqual(game.end(), Game.ENDS);
    Test.assertEqual(logRocks(game, 8), :gameOver);
    Test.assert(!game.nextEnd());
    Test.assertEqual(game.end(), Game.ENDS);
    return true;
}

(:test)
function gameKeepsTheLastFiveRocks(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    logRocks(game, 7);
    var history = game.history();
    Test.assertEqual(history.size(), Game.HISTORY);
    // Oldest first: rocks 3 to 7, thrown by the second, vice and skip
    Test.assertEqual(history[0][0], 3702);
    Test.assertEqual(history[0][3], 1);
    Test.assertEqual(history[4][0], 3706);
    Test.assertEqual(history[4][2], 1);
    Test.assertEqual(history[4][3], 3);
    return true;
}

(:test)
function gameRecordsScoreOnTheLastRock(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    game.logRock(3800, 7);
    game.setLastScore(3);
    Test.assertEqual(game.lastRock()[Game.SCORE], 3);
    return true;
}

(:test)
function gameUndoTakesBackOnlyThisEndsRocks(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    logRocks(game, 3);
    var undone = game.undo();
    Test.assertEqual(undone[Game.SPLIT], 3702);
    Test.assertEqual(game.rocks(), 2);
    Test.assertEqual(game.slot(), 2);
    Test.assertEqual(game.rockCount(-1), 2);
    game.undo();
    game.undo();
    Test.assert(game.undo() == null);
    logRocks(game, 8);
    game.nextEnd();
    // A new end has nothing to take back, even with rocks in the last one
    Test.assert(game.undo() == null);
    return true;
}

(:test)
function gameAveragesDrawSplitsByPlayerAndEnd(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    game.logRock(3800, 7);          // lead
    game.logRock(3900, 6);          // lead
    game.logRock(3000, SplitTable.HIT); // second's takeout: not a draw
    game.logRock(3700, SplitTable.BUTTON);
    Test.assertEqual(game.averageSplit(0, 0), 3850);
    Test.assertEqual(game.averageSplit(1, 0), 3700);
    Test.assertEqual(game.averageSplit(-1, 1), 3800);
    Test.assertEqual(game.averageSplit(2, 0), 0);
    return true;
}

(:test)
function gameShotPercentFromScores(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    Test.assertEqual(game.shotPercent(-1), -1);
    game.logRock(3800, 7);
    game.setLastScore(4);
    game.logRock(3800, 7);
    game.setLastScore(2);
    game.logRock(3800, 7);          // second, not scored
    Test.assertEqual(game.shotPercent(0), 75);
    Test.assertEqual(game.shotPercent(1), -1);
    Test.assertEqual(game.shotPercent(-1), 75);
    return true;
}

(:test)
function gameTotalsTheLineScore(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    Test.assert(!game.hasScore());
    game.setEndScore(1, 2);
    game.setEndScore(2, -1);
    game.setEndScore(3, 0);
    game.setEndScore(4, 3);
    Test.assert(game.hasScore());
    Test.assertEqual(game.totals()[0], 5);
    Test.assertEqual(game.totals()[1], 1);
    Test.assertEqual(game.endScore(2), -1);
    Test.assert(game.endScore(5) == null);
    return true;
}

(:test)
function gameSavesAndRestores(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    logRocks(game, 8);
    game.nextEnd();
    logRocks(game, 3);
    game.setEndScore(1, 2);
    var restored = new Game();
    Test.assert(restored.restore(game.save()));
    Test.assertEqual(restored.end(), 2);
    Test.assertEqual(restored.rocks(), 3);
    Test.assertEqual(restored.rockCount(-1), 11);
    Test.assertEqual(restored.totals()[0], 2);
    Test.assert(!restored.restore("junk"));
    Test.assertEqual(restored.end(), 0);
    return true;
}

(:test)
function gameSkipsTheWearersRocks(logger as Logger) as Boolean {
    var game = new Game();
    game.setMyPosition(0);
    game.start(Game.FOURS);
    // The lead wears the watch: the end starts on the second
    Test.assertEqual(game.slot(), 2);
    Test.assertEqual(game.nextPlayer(), 1);
    Test.assertEqual(game.slotState(0), Game.SLOT_MINE);
    Test.assertEqual(logRocks(game, 5), :rock);
    Test.assertEqual(logRocks(game, 1), :endComplete);
    Test.assertEqual(game.rocks(), 6);
    Test.assert(game.nextEnd());
    Test.assertEqual(game.nextPlayer(), 1);
    return true;
}

(:test)
function gameSkipsTheSkipsRocksAtTheEndOfAnEnd(logger as Logger) as Boolean {
    var game = new Game();
    game.setMyPosition(3);
    game.start(Game.FOURS);
    Test.assertEqual(logRocks(game, 5), :rock);
    // The vice's second rock is the last one to time
    Test.assertEqual(logRocks(game, 1), :endComplete);
    Test.assert(game.endComplete());
    return true;
}

(:test)
function gameSettingThePositionMidEndSkipsANextRockOfTheirs(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    logRocks(game, 4);
    game.setMyPosition(2);
    Test.assertEqual(game.slot(), 6);
    Test.assertEqual(game.nextPlayer(), 3);
    game.setMyPosition(-1);
    Test.assertEqual(game.slot(), 6);
    return true;
}

(:test)
function gameSkipRockPassesOverOneRock(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    logRocks(game, 1);
    Test.assertEqual(game.skipRock(), :rock);
    Test.assertEqual(game.slotState(0), Game.SLOT_THROWN);
    Test.assertEqual(game.slotState(1), Game.SLOT_SKIPPED);
    Test.assertEqual(game.slotState(2), Game.SLOT_NEXT);
    Test.assertEqual(game.slotState(3), Game.SLOT_AHEAD);
    Test.assertEqual(game.nextPlayer(), 1);
    // The second's rock is credited to the second, not the lead
    game.logRock(3700, SplitTable.BUTTON);
    Test.assertEqual(game.lastRock()[Game.PLAYER], 1);
    for (var i = 3; i < 8 - 1; ++i) {
        game.skipRock();
    }
    Test.assertEqual(game.skipRock(), :endComplete);
    Test.assert(game.skipRock() == null);
    return true;
}

(:test)
function gameUndoBringsBackRocksSkippedAfterIt(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    logRocks(game, 2);
    game.skipRock();
    game.skipRock();
    game.undo();
    Test.assertEqual(game.slot(), 1);
    Test.assertEqual(game.slotState(1), Game.SLOT_NEXT);
    return true;
}

(:test)
function gameRestoresItsSlotAndRejectsOldSaves(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    logRocks(game, 2);
    game.skipRock();
    var restored = new Game();
    Test.assert(restored.restore(game.save()));
    Test.assertEqual(restored.slot(), 3);
    Test.assertEqual(restored.rocks(), 2);
    var old = {"end" => 1, "rocks" => 2, "log" => [], "scores" => new Array<Number?>[Game.ENDS]};
    // Before slots, a game saved its rocks this end: it doesn't restore
    Test.assert(!restored.restore(old));
    return true;
}

(:test)
function gameUntimedHitIsLoggedForTheThrower(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    logRocks(game, 2);
    Test.assertEqual(game.logHit(), :rock);
    var rock = game.lastRock();
    Test.assertEqual(rock[Game.PLAYER], 1);
    Test.assertEqual(rock[Game.POSITION], SplitTable.HIT);
    Test.assertEqual(game.slotState(2), Game.SLOT_HIT);
    Test.assertEqual(game.hitCount(1), 1);
    // A hit has no split: it's left out of the draw average
    game.logRock(3800, SplitTable.BUTTON);
    Test.assertEqual(game.averageSplit(1, 0), 3800);
    return true;
}

(:test)
function gameMixedDoublesHasFiveRocksAnEnd(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.DOUBLES);
    Test.assertEqual(game.rocksPerEnd(), 5);
    Test.assertEqual(game.players(), 2);
    Test.assertEqual(game.maxPoints(), 6);
    // My partner throws first: I time the 1st and 5th, and throw 2nd-4th
    game.setFirstThrower(Game.PARTNER);
    Test.assertEqual(game.slot(), 0);
    Test.assertEqual(game.nextPlayer(), Game.PARTNER);
    Test.assertEqual(logRocks(game, 1), :rock);
    Test.assertEqual(game.slot(), 4);
    Test.assertEqual(game.slotState(1), Game.SLOT_MINE);
    Test.assertEqual(logRocks(game, 1), :endComplete);
    Test.assertEqual(game.rocks(), 2);
    return true;
}

(:test)
function gameMixedDoublesWhenIThrowFirst(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.DOUBLES);
    game.setFirstThrower(Game.ME);
    // My partner's 2nd, 3rd and 4th
    Test.assertEqual(game.slot(), 1);
    Test.assertEqual(logRocks(game, 2), :rock);
    Test.assertEqual(logRocks(game, 1), :endComplete);
    Test.assertEqual(game.history()[0][Game.PLAYER], Game.PARTNER);
    // The order carries into the next end until it's changed
    game.nextEnd();
    Test.assertEqual(game.slot(), 1);
    game.setFirstThrower(Game.PARTNER);
    Test.assertEqual(game.slot(), 0);
    return true;
}

(:test)
function gameMixedDoublesOrderLocksOnceARockIsLogged(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.DOUBLES);
    game.setFirstThrower(Game.PARTNER);
    logRocks(game, 1);
    game.setFirstThrower(Game.ME);
    Test.assertEqual(game.firstThrower(), Game.PARTNER);
    return true;
}

(:test)
function gameMixedDoublesIgnoresTheFoursPosition(logger as Logger) as Boolean {
    var game = new Game();
    game.setMyPosition(1);
    game.start(Game.DOUBLES);
    game.setFirstThrower(Game.PARTNER);
    Test.assertEqual(game.mine(), Game.ME);
    Test.assertEqual(game.slot(), 0);
    return true;
}

(:test)
function gameMixedDoublesSavesItsFormatAndOrder(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.DOUBLES);
    game.setFirstThrower(Game.ME);
    logRocks(game, 1);
    var restored = new Game();
    Test.assert(restored.restore(game.save()));
    Test.assert(restored.isDoubles());
    Test.assertEqual(restored.firstThrower(), Game.ME);
    Test.assertEqual(restored.slot(), 2);
    return true;
}

(:test)
function gameMyRocksAreUpOnceTheRockBeforeThemIsLogged(logger as Logger) as Boolean {
    var game = new Game();
    game.setMyPosition(1);
    game.start(Game.FOURS);
    // The second: nothing up until the lead's last rock is logged
    Test.assertEqual(game.dueMine().size(), 0);
    logRocks(game, 1);
    Test.assertEqual(game.dueMine().size(), 0);
    logRocks(game, 1);
    var due = game.dueMine();
    Test.assertEqual(due.size(), 2);
    Test.assertEqual(due[0], 2);
    Test.assertEqual(due[1], 3);
    Test.assertEqual(game.mineNumber(3), 2);
    game.markMine(2, Game.MADE);
    game.markMine(3, Game.NO_SCORE);
    // Passed over with Back: not asked for again, and not an attempt
    Test.assertEqual(game.dueMine().size(), 0);
    Test.assertEqual(game.myShots()[0], 1);
    Test.assertEqual(game.myShots()[1], 1);
    Test.assertEqual(game.shotPercent(1), 100);
    return true;
}

(:test)
function gameTheLeadsRocksAreUpAsTheEndStarts(logger as Logger) as Boolean {
    var game = new Game();
    game.setMyPosition(0);
    game.start(Game.FOURS);
    Test.assertEqual(game.dueMine().size(), 2);
    game.markMine(0, Game.MADE);
    game.markMine(1, Game.MISSED);
    logRocks(game, 6);
    game.nextEnd();
    var due = game.dueMine();
    Test.assertEqual(due.size(), 2);
    Test.assertEqual(due[0], 0);
    Test.assertEqual(game.shotPercent(0), 50);
    return true;
}

(:test)
function gameTheSkipsRocksAreUpAfterTheVicesLast(logger as Logger) as Boolean {
    var game = new Game();
    game.setMyPosition(3);
    game.start(Game.FOURS);
    logRocks(game, 5);
    Test.assertEqual(game.dueMine().size(), 0);
    Test.assertEqual(logRocks(game, 1), :endComplete);
    var due = game.dueMine();
    Test.assertEqual(due.size(), 2);
    Test.assertEqual(due[0], 6);
    Test.assertEqual(due[1], 7);
    return true;
}

(:test)
function gameMixedDoublesMyRocksAreUpInTurn(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.DOUBLES);
    // I throw first: my 1st rock is up as the end starts
    game.setFirstThrower(Game.ME);
    var due = game.dueMine();
    Test.assertEqual(due.size(), 1);
    Test.assertEqual(due[0], 0);
    game.markMine(0, Game.MADE);
    logRocks(game, 2);
    Test.assertEqual(game.dueMine().size(), 0);
    // My partner's last rock (the 4th): my 5th is up
    logRocks(game, 1);
    due = game.dueMine();
    Test.assertEqual(due.size(), 1);
    Test.assertEqual(due[0], 4);
    Test.assertEqual(game.mineNumber(4), 2);
    // My partner throws first next end: my three are up after their 1st
    game.nextEnd();
    game.setFirstThrower(Game.PARTNER);
    Test.assertEqual(game.dueMine().size(), 0);
    logRocks(game, 1);
    Test.assertEqual(game.dueMine().size(), 3);
    return true;
}

(:test)
function gameFinalScoreStandsInForTheEnds(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    Test.assert(!game.hasScore());
    Test.assertEqual(game.summary(), "");
    game.setEndScore(1, 2);
    game.setFinalScore(7, 4);
    Test.assert(game.hasScore());
    Test.assert(game.hasEndScores());
    Test.assertEqual(game.totals()[0], 7);
    Test.assertEqual(game.totals()[1], 4);
    Test.assertEqual(game.summary(), "Won 7-4");
    game.setFinalScore(3, 5);
    Test.assertEqual(game.summary(), "Lost 3-5");
    return true;
}

(:test)
function gameSummaryHasMyShotsMade(logger as Logger) as Boolean {
    var game = new Game();
    game.setMyPosition(0);
    game.start(Game.FOURS);
    logRocks(game, 1);
    game.markMine(0, Game.MADE);
    game.markMine(1, Game.MISSED);
    Test.assertEqual(game.summary(), "Made 1/2 (50%)");
    game.setFinalScore(6, 6);
    Test.assertEqual(game.summary(), "Tied 6-6 · Made 1/2 (50%)");
    return true;
}

(:test)
function gameSavesMyScoresAndTheFinalScore(logger as Logger) as Boolean {
    var game = new Game();
    game.setMyPosition(0);
    game.start(Game.FOURS);
    logRocks(game, 1);
    game.markMine(0, Game.MISSED);
    game.setFinalScore(5, 2);
    var restored = new Game();
    restored.setMyPosition(0);
    Test.assert(restored.restore(game.save()));
    Test.assertEqual(restored.myShots()[0], 0);
    Test.assertEqual(restored.myShots()[1], 1);
    Test.assertEqual(restored.dueMine().size(), 1);
    Test.assertEqual(restored.totals()[0], 5);
    // Saved before either existed: still restores, with neither
    var old = game.save();
    old.remove("mine");
    old.remove("final");
    Test.assert(restored.restore(old));
    Test.assertEqual(restored.myShots()[1], 0);
    Test.assert(!restored.hasScore());
    return true;
}

(:test)
function gameRestoresOldPositionsAsTodays(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    game.logRock(3600, SplitTable.BACK_12);
    var saved = game.save();
    var restored = new Game();
    Test.assert(restored.restore(saved));
    Test.assertEqual(restored.lastRock()[Game.POSITION], SplitTable.BACK_12);
    // Saved before the back 8 and back 12: old 10 was the back of house
    saved.remove("positions");
    var log = saved["log"] as Array<Array<Number> >;
    log[0][Game.POSITION] = 10;
    Test.assert(restored.restore(saved));
    Test.assertEqual(restored.lastRock()[Game.POSITION], SplitTable.BACK_12);
    return true;
}

(:test)
function gameMyAccuracyIsShotsMadeOverShotsAttempted(logger as Logger) as Boolean {
    Test.assertEqual(Game.madePercent(0, 0), -1);
    Test.assertEqual(Game.madePercent(2, 3), 67);
    Test.assertEqual(Game.madePercent(1, 8), 13);
    Test.assertEqual(Game.madePercent(0, 4), 0);
    Test.assertEqual(Game.madePercent(5, 5), 100);
    return true;
}

(:test)
function gameThrowersAreTheirPositionOrDoublesPlayer(logger as Logger) as Boolean {
    var game = new Game();
    game.start(Game.FOURS);
    Test.assertEqual(game.thrower(game.nextPlayer()), 0);
    Test.assertEqual(game.thrower(3), 3);
    game.start(Game.DOUBLES);
    // Mixed doubles throwers don't mix with a fours second's marks
    Test.assertEqual(game.thrower(Game.PARTNER), Game.DOUBLES_THROWERS + Game.PARTNER);
    return true;
}

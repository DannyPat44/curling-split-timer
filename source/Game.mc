import Toybox.Lang;

//! One game, of 8 ends, in one of two formats:
//!
//! - Fours: our 8 rocks an end, two each for lead, second, vice and skip.
//! - Mixed doubles: our 5 thrown rocks an end (the sixth is placed). One
//!   player throws the 1st and 5th, the other the 2nd to 4th, and who
//!   throws first can change each end. The players are me (the wearer) and
//!   my partner.
//!
//! Each end has a slot per rock, in throwing order. A rock counts when it's
//! logged: timed and marked, or a hit (not timed). A rock that isn't logged
//! (the wearer's own, or one that was missed) is skipped. The wearer's own
//! rocks can't be timed, but once they're thrown the wearer says whether
//! each made the shot they set out to play, for their accuracy. Each end can record its score, and the game a final
//! score that stands in for the ends'.
class Game {
    static const FOURS = 0;
    static const DOUBLES = 1;

    static const ENDS = 8;
    static const HISTORY = 5;
    // In mixed doubles the wearer is player 0 and the partner player 1
    static const ME = 0;
    static const PARTNER = 1;

    // Fields of a logged rock
    static const SPLIT = 0;
    static const POSITION = 1;
    static const END = 2;
    static const PLAYER = 3;
    static const SCORE = 4;
    static const SLOT = 5;

    // What each of an end's slots shows on the rock row
    static const SLOT_THROWN = 0;
    static const SLOT_SKIPPED = 1;
    static const SLOT_NEXT = 2;
    static const SLOT_AHEAD = 3;
    static const SLOT_MINE = 4;
    static const SLOT_HIT = 5;

    // Positions from here on are takeout weight, left out of draw splits
    static const TAKEOUT_FROM = SplitTable.THROUGH;
    // A score of 0-4 per rock; NO_SCORE until scored
    static const MAX_SCORE = 4;
    static const NO_SCORE = -1;

    private var _format as Number = FOURS;
    private var _end as Number = 0;
    // The next slot this end: rocks logged or skipped so far
    private var _slot as Number = 0;
    // Fours: the wearer's position (0-3), whose rocks are skipped, or -1
    private var _myPosition as Number = -1;
    // Mixed doubles: who throws this end's first and last rock, ME or PARTNER
    private var _firstThrower as Number = PARTNER;
    // Every rock this game, oldest first: [split, position, end, player, score, slot]
    private var _log as Array<Array<Number> > = [] as Array<Array<Number> >;
    // Points per end: positive for us, negative for them, 0 blank, null not entered
    private var _endScores as Array<Number?> = new Array<Number?>[ENDS];
    // The wearer's rocks marked MADE, MISSED or passed over (NO_SCORE):
    // [end, slot, result]
    private var _mine as Array<Array<Number> > = [] as Array<Array<Number> >;
    // The final score [us, them], entered after the game, or null
    private var _final as Array<Number>? = null;
    // Fields of a wearer's scored rock
    static const MINE_END = 0;
    static const MINE_SLOT = 1;
    static const MINE_RESULT = 2;
    // Whether the wearer made the shot they set out to play
    static const MADE = 1;
    static const MISSED = 0;

    function initialize() {
    }

    //! Start a game in a format (FOURS or DOUBLES)
    function start(format as Number) as Void {
        reset();
        _format = format == DOUBLES ? DOUBLES : FOURS;
        _end = 1;
        skipMine();
    }

    //! A new, unstarted game; the wearer's position is kept
    function reset() as Void {
        _end = 0;
        _slot = 0;
        _log = [] as Array<Array<Number> >;
        _endScores = new Array<Number?>[ENDS];
        _mine = [] as Array<Array<Number> >;
        _final = null;
    }

    function format() as Number {
        return _format;
    }

    function isDoubles() as Boolean {
        return _format == DOUBLES;
    }

    //! Rocks thrown by our team each end
    function rocksPerEnd() as Number {
        return isDoubles() ? 5 : 8;
    }

    //! Players on our team
    function players() as Number {
        return isDoubles() ? 2 : 4;
    }

    //! The most an end can score (mixed doubles counts the placed rock)
    function maxPoints() as Number {
        return isDoubles() ? 6 : 8;
    }

    //! The current end, or 0 before the game starts
    function end() as Number {
        return _end;
    }

    //! The next slot this end, or rocksPerEnd() once every rock is logged
    //! or skipped
    function slot() as Number {
        return _slot;
    }

    //! True once every rock of this end is logged or skipped
    function endComplete() as Boolean {
        return _slot >= rocksPerEnd();
    }

    //! Rocks logged this end
    function rocks() as Number {
        var count = 0;
        for (var i = _log.size() - 1; i >= 0 && _log[i][END] == _end; --i) {
            count++;
        }
        return count;
    }

    //! Who throws a slot: fours 0 lead to 3 skip; doubles ME or PARTNER
    function playerOf(slot as Number) as Number {
        if (isDoubles()) {
            var outside = slot == 0 || slot == rocksPerEnd() - 1;
            return outside ? _firstThrower : 1 - _firstThrower;
        }
        return slot / 2;
    }

    //! Who threw a rock, for the ice marks that outlast the game: a fours
    //! position (0 lead to 3 skip), or 10 + ME or PARTNER in mixed doubles
    //! (see Labels.thrower)
    function thrower(player as Number) as Number {
        return isDoubles() ? DOUBLES_THROWERS + player : player;
    }

    static const DOUBLES_THROWERS = 10;

    //! Who throws next (the last thrower once the end is complete)
    function nextPlayer() as Number {
        var last = rocksPerEnd() - 1;
        return playerOf(_slot < last ? _slot : last);
    }

    //! The player whose rocks the wearer throws, or -1 if none
    function mine() as Number {
        return isDoubles() ? ME : _myPosition;
    }

    function myPosition() as Number {
        return _myPosition;
    }

    //! Fours: the wearer's position, whose rocks can't be timed and are
    //! skipped from now on (including the next rock, if it's theirs)
    //! @param position 0-3, or -1 to time every rock
    function setMyPosition(position as Number) as Void {
        _myPosition = position;
        if (_end > 0) {
            skipMine();
        }
    }

    function firstThrower() as Number {
        return _firstThrower;
    }

    //! Mixed doubles: who throws this end's first and last rocks. Only
    //! before any rock of the end is logged.
    function setFirstThrower(player as Number) as Void {
        if (rocks() > 0) {
            return;
        }
        _firstThrower = player == ME ? ME : PARTNER;
        _slot = 0;
        skipMine();
    }

    //! How a slot of this end shows on the rock row: SLOT_THROWN, SLOT_HIT,
    //! SLOT_MINE (the wearer's), SLOT_SKIPPED, SLOT_NEXT or SLOT_AHEAD
    function slotState(slot as Number) as Number {
        for (var i = _log.size() - 1; i >= 0 && _log[i][END] == _end; --i) {
            if (_log[i][SLOT] == slot) {
                return _log[i][POSITION] == SplitTable.HIT ? SLOT_HIT : SLOT_THROWN;
            }
        }
        if (playerOf(slot) == mine()) {
            return SLOT_MINE;
        }
        if (slot >= _slot) {
            return slot == _slot ? SLOT_NEXT : SLOT_AHEAD;
        }
        return SLOT_SKIPPED;
    }

    //! The last few rocks, oldest first
    function history() as Array<Array<Number> > {
        var from = _log.size() - HISTORY;
        return _log.slice(from > 0 ? from : 0, null);
    }

    //! Log a marked rock.
    //! @return :gameOver after the last rock of the last end, :endComplete
    //!     after the last rock of any other end, otherwise :rock
    function logRock(split as Number, position as Number) as Symbol {
        _log.add([split, position, _end, nextPlayer(), NO_SCORE, _slot]);
        return advance();
    }

    //! Log the next rock as a hit that wasn't timed
    //! @return as logRock(), or null if the end has no rocks left
    function logHit() as Symbol? {
        return endComplete() ? null : logRock(0, SplitTable.HIT);
    }

    //! Pass over the next rock without logging it (it wasn't timed)
    //! @return as logRock(), or null if the end has no rocks left
    function skipRock() as Symbol? {
        return endComplete() ? null : advance();
    }

    private function advance() as Symbol {
        _slot++;
        skipMine();
        if (!endComplete()) {
            return :rock;
        }
        return _end >= ENDS ? :gameOver : :endComplete;
    }

    //! Move past the wearer's own rocks
    private function skipMine() as Void {
        var mine = mine();
        while (_slot < rocksPerEnd() && playerOf(_slot) == mine) {
            _slot++;
        }
    }

    function lastRock() as Array<Number>? {
        return _log.size() > 0 ? _log[_log.size() - 1] : null;
    }

    function setLastScore(score as Number) as Void {
        var rock = lastRock();
        if (rock != null) {
            rock[SCORE] = score;
        }
    }

    //! The wearer's rocks this end that are up and not yet marked, oldest
    //! first. A rock is up once the teammate's rock before it is logged or
    //! skipped (at the start of the end when the wearer throws first), so
    //! the question is waiting when they throw it.
    function dueMine() as Array<Number> {
        var due = [] as Array<Number>;
        var mine = mine();
        if (mine < 0) {
            return due;
        }
        // The rotation moves past the wearer's rocks as soon as they're up
        for (var s = 0; s < _slot; ++s) {
            if (playerOf(s) == mine && !isScoredMine(s)) {
                due.add(s);
            }
        }
        return due;
    }

    private function isScoredMine(slot as Number) as Boolean {
        for (var i = _mine.size() - 1; i >= 0 && _mine[i][MINE_END] == _end; --i) {
            if (_mine[i][MINE_SLOT] == slot) {
                return true;
            }
        }
        return false;
    }

    //! Mark one of the wearer's rocks this end MADE or MISSED, or NO_SCORE
    //! to pass over it (it won't be asked for again, and doesn't count)
    function markMine(slot as Number, result as Number) as Void {
        if (!isScoredMine(slot)) {
            _mine.add([_end, slot, result] as Array<Number>);
        }
    }

    //! Which of the wearer's rocks this end a slot is: 1 for their first
    function mineNumber(slot as Number) as Number {
        var count = 0;
        for (var s = 0; s <= slot; ++s) {
            if (playerOf(s) == mine()) {
                count++;
            }
        }
        return count;
    }

    //! The wearer's shots this game: [made, attempted] (passed-over rocks
    //! aren't attempts)
    function myShots() as Array<Number> {
        var made = 0;
        var attempted = 0;
        for (var i = 0; i < _mine.size(); ++i) {
            var result = _mine[i][MINE_RESULT];
            if (result != NO_SCORE) {
                attempted++;
                made += result == MADE ? 1 : 0;
            }
        }
        return [made, attempted];
    }

    //! The share of shots made, 0-100 rounded, or -1 with none attempted
    static function madePercent(made as Number, attempted as Number) as Number {
        return attempted > 0 ? (made * 200 + attempted) / (attempted * 2) : -1;
    }

    //! Take back the last rock of this end; rocks skipped after it come
    //! back too, so it's next again
    //! @return the rock taken back, or null if this end has none
    function undo() as Array<Number>? {
        var rock = lastRock();
        if (rock == null || rock[END] != _end) {
            return null;
        }
        _log = _log.slice(0, _log.size() - 1);
        _slot = rock[SLOT];
        return rock;
    }

    //! Move to the next end; there's none after the last
    //! @return false if the game is already on its last end
    function nextEnd() as Boolean {
        if (_end >= ENDS) {
            return false;
        }
        _end++;
        _slot = 0;
        skipMine();
        return true;
    }

    //! Record an end's score: positive for us, negative for them, 0 blank
    function setEndScore(end as Number, points as Number) as Void {
        if (end >= 1 && end <= ENDS) {
            _endScores[end - 1] = points;
        }
    }

    function endScore(end as Number) as Number? {
        return end >= 1 && end <= ENDS ? _endScores[end - 1] : null;
    }

    //! Set the final score, entered after the game. It's the game's score
    //! from then on, whatever the ends say.
    function setFinalScore(us as Number, them as Number) as Void {
        _final = [us, them] as Array<Number>;
    }

    //! Total points: [us, them], the final score if one was entered
    function totals() as Array<Number> {
        var final = _final;
        if (final != null) {
            return final;
        }
        var us = 0;
        var them = 0;
        for (var i = 0; i < ENDS; ++i) {
            var points = _endScores[i];
            if (points != null && points > 0) {
                us += points;
            } else if (points != null) {
                them -= points;
            }
        }
        return [us, them];
    }

    //! True once the game has a score: a final score or any end's
    function hasScore() as Boolean {
        return _final != null || hasEndScores();
    }

    //! True once any end has a score
    function hasEndScores() as Boolean {
        for (var i = 0; i < ENDS; ++i) {
            if (_endScores[i] != null) {
                return true;
            }
        }
        return false;
    }

    //! Average draw split (ms) of matching rocks, or 0 if none: takeouts
    //! are left out because their splits say nothing about draw weight.
    //! @param player a player, or -1 for the whole team
    //! @param end an end, or 0 for the whole game
    function averageSplit(player as Number, end as Number) as Number {
        var total = 0;
        var count = 0;
        for (var i = 0; i < _log.size(); ++i) {
            var rock = _log[i];
            if (rock[POSITION] < TAKEOUT_FROM && rock[SPLIT] > 0 && matches(rock, player, end)) {
                total += rock[SPLIT];
                count++;
            }
        }
        return count > 0 ? total / count : 0;
    }

    //! Shot percentage (0-100), or -1 if none are scored: the wearer's
    //! shots made, or a teammate's 0-4 scores (from games before the wearer
    //! marked their own shots)
    //! @param player a player, or -1 for the teammates' scores together
    function shotPercent(player as Number) as Number {
        if (player >= 0 && player == mine()) {
            var shots = myShots();
            return madePercent(shots[0], shots[1]);
        }
        var total = 0;
        var count = 0;
        for (var i = 0; i < _log.size(); ++i) {
            var rock = _log[i];
            if (rock[SCORE] != NO_SCORE && matches(rock, player, 0)) {
                total += rock[SCORE];
                count++;
            }
        }
        return percent(total, count);
    }

    //! A shot percentage from a total 0-4 score over `count` rocks, or -1
    static function percent(total as Number, count as Number) as Number {
        return count > 0 ? (total * 100 + count * MAX_SCORE / 2) / (count * MAX_SCORE) : -1;
    }

    //! One line for the activity: "Won 7-4 · Made 9/12 (75%)", or "" with
    //! no score and none of the wearer's shots marked
    function summary() as String {
        var text = "";
        if (hasScore()) {
            var t = totals();
            text = (t[0] > t[1] ? "Won " : (t[0] < t[1] ? "Lost " : "Tied ")) + t[0] + "-" + t[1];
        }
        var shots = myShots();
        if (shots[1] > 0) {
            text += (text.length() > 0 ? " · " : "") + "Made " + shots[0] + "/" + shots[1]
                + " (" + madePercent(shots[0], shots[1]) + "%)";
        }
        return text;
    }

    //! Rocks a player has had logged this game (-1 for the whole team)
    function rockCount(player as Number) as Number {
        var count = 0;
        for (var i = 0; i < _log.size(); ++i) {
            if (matches(_log[i], player, 0)) {
                count++;
            }
        }
        return count;
    }

    //! Hits a player has thrown this game (-1 for the whole team)
    function hitCount(player as Number) as Number {
        var count = 0;
        for (var i = 0; i < _log.size(); ++i) {
            if (_log[i][POSITION] == SplitTable.HIT && matches(_log[i], player, 0)) {
                count++;
            }
        }
        return count;
    }

    private function matches(rock as Array<Number>, player as Number, end as Number) as Boolean {
        return (player < 0 || rock[PLAYER] == player) && (end <= 0 || rock[END] == end);
    }

    //! Everything needed to pick the game up again after the app closes
    function save() as Dictionary {
        return {"format" => _format, "end" => _end, "slot" => _slot, "first" => _firstThrower,
            "log" => _log, "scores" => _endScores, "mine" => _mine, "final" => _final,
            "positions" => SplitTable.POSITIONS};
    }

    //! Restore a saved game
    //! @return false (and a reset game) if `saved` isn't a saved game
    function restore(saved) as Boolean {
        reset();
        if (!(saved instanceof Dictionary)) {
            return false;
        }
        var format = saved.get("format");
        var end = saved.get("end");
        // Games saved before slots (with "rocks") don't restore
        var slot = saved.get("slot");
        var first = saved.get("first");
        var log = saved.get("log");
        var scores = saved.get("scores");
        if (!(format instanceof Number) || !(end instanceof Number) || !(slot instanceof Number)
                || !(first instanceof Number) || !(log instanceof Array)
                || !(scores instanceof Array) || scores.size() != ENDS || end < 1 || end > ENDS) {
            return false;
        }
        _format = format == DOUBLES ? DOUBLES : FOURS;
        _end = end;
        _slot = slot;
        _firstThrower = first == ME ? ME : PARTNER;
        _log = log as Array<Array<Number> >;
        // Games saved before the back 8 and back 12 have the old positions
        if (saved.get("positions") != SplitTable.POSITIONS) {
            for (var i = 0; i < _log.size(); ++i) {
                _log[i][POSITION] = SplitTable.fromOldPosition(_log[i][POSITION]);
            }
        }
        _endScores = scores as Array<Number?>;
        // Games saved before the wearer's scores and the final score lack them
        var mine = saved.get("mine");
        if (mine instanceof Array) {
            _mine = mine as Array<Array<Number> >;
        }
        var final = saved.get("final");
        if (final instanceof Array && final.size() == 2) {
            _final = final as Array<Number>;
        }
        skipMine();
        return true;
    }
}

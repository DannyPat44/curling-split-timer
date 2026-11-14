import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Lang;

//! Writes the game into the activity so Garmin Connect shows it: each marked
//! rock's split on the timeline, each end's average draw split and points in
//! the laps, and the game's points, each player's draw split, the share of
//! the wearer's shots made, and a line with the score and shots made, in the
//! summary.
//!
//! Garmin Connect labels a field by its id (resources/contributions), so a
//! label belongs to one id: the fours players' draw splits are 8-11 (Lead to
//! Skip) and mixed doubles' are 17 (Me) and 18 (Partner). Sweeping goes in as strokes each second (timeline), each
//! end (laps) and the whole game (summary).
class GameFields {
    private var _strokes as Field;
    private var _endStrokes as Field;
    private var _gameStrokes as Field;
    private var _split as Field;
    private var _endSplit as Field;
    private var _endPoints as Field;
    private var _pointsFor as Field;
    private var _pointsAgainst as Field;
    private var _playerSplits as Array<Field> = [] as Array<Field>;
    private var _myShots as Field;
    private var _summary as Field;
    // Bytes in the summary, including its terminator
    private const SUMMARY_BYTES = 48;

    //! @param format Game.FOURS or Game.DOUBLES: names the player fields
    function initialize(session as Session, format as Number) {
        var record = {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "s"};
        var lap = {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "s"};
        var summary = {:mesgType => FitContributor.MESG_TYPE_SESSION};
        _strokes = session.createField("Brush strokes", 0, FitContributor.DATA_TYPE_UINT8,
            {:mesgType => FitContributor.MESG_TYPE_RECORD});
        _endStrokes = session.createField("End brush strokes", 1, FitContributor.DATA_TYPE_UINT16,
            {:mesgType => FitContributor.MESG_TYPE_LAP});
        _gameStrokes = session.createField("Total brush strokes", 2, FitContributor.DATA_TYPE_UINT16, summary);
        _split = session.createField("Split", 3, FitContributor.DATA_TYPE_FLOAT, record);
        _endSplit = session.createField("End draw split", 4, FitContributor.DATA_TYPE_FLOAT, lap);
        _endPoints = session.createField("End points", 5, FitContributor.DATA_TYPE_SINT8,
            {:mesgType => FitContributor.MESG_TYPE_LAP});
        _pointsFor = session.createField("Points for", 6, FitContributor.DATA_TYPE_UINT8, summary);
        _pointsAgainst = session.createField("Points against", 7, FitContributor.DATA_TYPE_UINT8, summary);
        // A line of text: Connect IQ apps can't write the activity's notes
        _summary = session.createField("Game", 16, FitContributor.DATA_TYPE_STRING,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :count => SUMMARY_BYTES});
        _myShots = session.createField("My shots made", 19, FitContributor.DATA_TYPE_UINT8,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "%"});
        var doubles = format == Game.DOUBLES;
        var first = doubles ? 17 : 8;
        for (var i = 0; i < (doubles ? 2 : 4); ++i) {
            _playerSplits.add(session.createField(Labels.player(format, i) + " draw split", first + i,
                FitContributor.DATA_TYPE_FLOAT, {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "s"}));
        }
    }

    //! Sweeping so far: strokes in the last second, this end and the game
    function strokes(recent as Number, end as Number, game as Number) as Void {
        _strokes.setData(recent < 255 ? recent : 255);
        _endStrokes.setData(end);
        _gameStrokes.setData(game);
    }

    //! Bring every field up to date with the game
    function update(game as Game) as Void {
        var rock = game.lastRock();
        if (rock != null && rock[Game.SPLIT] > 0) {
            _split.setData(rock[Game.SPLIT] / 1000.0);
        }
        _endSplit.setData(game.averageSplit(-1, game.end()) / 1000.0);
        var points = game.endScore(game.end());
        _endPoints.setData(points != null ? points : 0);
        var totals = game.totals();
        _pointsFor.setData(totals[0]);
        _pointsAgainst.setData(totals[1]);
        for (var i = 0; i < _playerSplits.size(); ++i) {
            _playerSplits[i].setData(game.averageSplit(i, 0) / 1000.0);
        }
        // Left empty until a shot of the wearer's is marked
        var shots = game.myShots();
        if (shots[1] > 0) {
            _myShots.setData(Game.madePercent(shots[0], shots[1]));
        }
        var summary = game.summary();
        // Characters, not bytes: "·" is two, so leave room for it and the end
        var most = SUMMARY_BYTES - 8;
        _summary.setData(summary.length() > most ? summary.substring(0, most) : summary);
    }
}

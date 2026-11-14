import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.SensorLogging;
import Toybox.System;
import Toybox.Time;

//! One game on the watch: the split stopwatch, sweeping, the activity
//! recording, and what's kept in storage. The rules are Game's, the ice is
//! SplitTable's and the activity's fields are GameFields'; this ties them
//! to the watch.
class GameSession {
    // Kept in storage between runs of the app
    private const ICE_KEY = "iceMarks";
    // Ice marks from before the back 8 and back 12, in the old positions
    private const OLD_ICE_KEY = "recordedTimes";
    // The wearer's shots from every saved game (see Accuracy). "myAccuracy"
    // held 0-4 scores, from before shots were made or missed.
    private const ACCURACY_KEY = "myShotsMade";
    private const OLD_ACCURACY_KEY = "myAccuracy";
    // The game in progress, saved after every change in case the app closes
    private const GAME_KEY = "game";
    // A saved game older than this is a new day, not one to pick up again
    private const RESUME_WITHIN = 6 * 3600;
    // Accelerometer samples a second, at most
    private const SAMPLES_PER_SECOND = 25;

    private var _game as Game = new Game();
    private var _table as SplitTable;
    // The ice marks before the last rock was logged, so undo can restore them
    private var _marksBeforeLastRock as Array<Array<Number> >? = null;

    // The activity, from the first Start until it's saved or discarded
    private var _recording as Session? = null;
    private var _fields as GameFields? = null;
    // Raw accelerometer data, written into the activity alongside it
    private var _accelerometerLog as SensorLogger? = null;

    private var _sweeps as SweepCounter;
    private var _samplesPerSecond as Number;
    private var _endStrokes as Number = 0;
    private var _gameStrokes as Number = 0;

    // The stopwatch: when it started (System.getTimer(), 0 when stopped)
    // and the split it shows
    private var _startedAt as Number = 0;
    private var _split as Number = 0;
    // A split is logged at most once
    private var _splitLogged as Boolean = false;
    // Where the last split's rock was logged, shown instead of the
    // prediction, or -1
    private var _loggedPosition as Number = -1;

    function initialize() {
        var rate = Sensor.getMaxSampleRate();
        _samplesPerSecond = rate < SAMPLES_PER_SECOND ? rate : SAMPLES_PER_SECOND;
        _sweeps = new SweepCounter(_samplesPerSecond);
        try {
            Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
            _accelerometerLog = new SensorLogging.SensorLogger({:accelerometer => {:enabled => true}});
        } catch (e) {
            // No heart rate or logging on this watch: the game still runs
            System.println(e.getErrorMessage());
        }
        _table = new SplitTable(loadMarks());
        _game.setMyPosition(Settings.myPosition());
    }

    function getGame() as Game {
        return _game;
    }

    function getTable() as SplitTable {
        return _table;
    }

    // ---------------------------------------------------------------- recording

    //! Start the game's activity, or carry on with it after a pause. A new
    //! game is started (unless a saved one was picked up), and sweeping is
    //! counted while it records.
    function onStart() as Void {
        if (_recording == null) {
            var options = {:name => "Curling", :sport => Activity.SPORT_GENERIC};
            var log = _accelerometerLog;
            if (log != null) {
                options[:sensorLogger] = log;
            }
            var recording = ActivityRecording.createSession(options);
            _recording = recording;
            if (_game.end() == 0) {
                _game.start(Settings.format());
            }
            _fields = new GameFields(recording, _game.format());
            changed();
        }
        try {
            Sensor.registerSensorDataListener(method(:onSensorData), {:period => 1,
                :accelerometer => {:enabled => true, :sampleRate => _samplesPerSecond}});
        } catch (e) {
            System.println(e.getErrorMessage());
        }
        var recording = _recording;
        if (recording != null && !recording.isRecording()) {
            recording.start();
        }
    }

    //! Pause: stop recording and counting sweeps (the game menu, or the app
    //! closing)
    function onStop() as Void {
        Sensor.unregisterSensorDataListener();
        var recording = _recording;
        if (recording != null && recording.isRecording()) {
            recording.stop();
        }
    }

    //! A second of accelerometer data: count its sweeping
    function onSensorData(data as SensorData) as Void {
        var accel = data.accelerometerData;
        if (accel == null) {
            return;
        }
        var strokes = _sweeps.add(accel.y);
        _endStrokes += strokes;
        _gameStrokes += strokes;
        var fields = _fields;
        if (fields != null) {
            fields.strokes(strokes, _endStrokes, _gameStrokes);
        }
    }

    //! Brush strokes this end
    function endStrokes() as Number {
        return _endStrokes;
    }

    function isSessionActive() as Boolean {
        return _recording != null;
    }

    function isSessionRecording() as Boolean {
        var recording = _recording;
        return recording != null && recording.isRecording();
    }

    //! Save or discard the activity and get ready for a new game. The
    //! activity is closed before its fields are let go: a field dropped
    //! first is left out of the file.
    function resetSession(save as Boolean) as Void {
        var recording = _recording;
        if (recording != null) {
            if (save) {
                recording.save();
            } else {
                recording.discard();
            }
        }
        if (save) {
            Application.Storage.setValue(ACCURACY_KEY, Accuracy.add(myAccuracy(), _game.myShots()));
            Application.Storage.deleteValue(OLD_ACCURACY_KEY);
        }
        _recording = null;
        _fields = null;
        _game.reset();
        _marksBeforeLastRock = null;
        _gameStrokes = 0;
        clearEnd();
        Application.Storage.deleteValue(GAME_KEY);
    }

    //! Finish the end, with its score if one was entered, and start the next
    //! (there's none after the last)
    //! @param points positive for us, negative for them, 0 blank, or null
    //! @return true if a new end started
    function completeEnd(points as Number?) as Boolean {
        if (points != null) {
            _game.setEndScore(_game.end(), points);
        }
        // The end's lap fields are written before its lap closes
        changed();
        var recording = _recording;
        if (recording == null || !_game.nextEnd()) {
            return false;
        }
        recording.addLap();
        _marksBeforeLastRock = null;
        clearEnd();
        changed();
        return true;
    }

    //! A new end: a clear sheet and no strokes
    private function clearEnd() as Void {
        _endStrokes = 0;
        _startedAt = 0;
        _split = 0;
        _splitLogged = true;
        _loggedPosition = -1;
    }

    // ---------------------------------------------------------------- stopwatch

    //! The back line: start timing a rock
    function startTimer() as Void {
        _startedAt = System.getTimer();
        _split = 0;
        _splitLogged = false;
        _loggedPosition = -1;
    }

    //! The hog line: stop timing. The split waits to be logged.
    function stopTimer() as Void {
        if (isStopwatchRunning()) {
            getStopwatchValue();
            _startedAt = 0;
        }
    }

    //! Throw the timing away (running or waiting to be logged): started too
    //! early, stopped too early, or not a rock worth timing
    function cancelTimer() as Void {
        _startedAt = 0;
        _split = 0;
        _splitLogged = true;
        _loggedPosition = -1;
    }

    function isStopwatchRunning() as Boolean {
        return _startedAt != 0;
    }

    //! The split in ms: running while timing, then the one stopped
    function getStopwatchValue() as Number {
        if (isStopwatchRunning()) {
            _split = System.getTimer() - _startedAt;
        }
        return _split;
    }

    //! True when the last split can still be logged
    function canMark() as Boolean {
        return _split > 0 && !_splitLogged && !isStopwatchRunning();
    }

    //! Where the split predicts the rock stops
    function getStopwatchEstimate() as Number {
        return _table.estimate(_split);
    }

    //! Where the split's rock is shown: where it was logged once it's
    //! logged, otherwise where the split predicts
    function getShownPosition() as Number {
        return _loggedPosition >= 0 && !isStopwatchRunning() ? _loggedPosition : getStopwatchEstimate();
    }

    //! Where the split's rock would stop, in feet past the far tee
    function getStopwatchFeet() as Float {
        return _table.feet(getStopwatchValue());
    }

    // ---------------------------------------------------------------- rocks

    //! Log the last split's rock where it stopped: it teaches the ice and is
    //! credited to its thrower
    //! @return the game's outcome (:rock, :endComplete or :gameOver), or
    //!     null if there's no split to log
    function addSplit(position as Number) as Symbol? {
        if (!canMark()) {
            return null;
        }
        _splitLogged = true;
        _marksBeforeLastRock = _table.marks().slice(0, null);
        _table.mark(_split, position, _game.thrower(_game.nextPlayer()));
        saveMarks();
        var outcome = _game.logRock(_split, position);
        _loggedPosition = position;
        changed();
        return outcome;
    }

    //! Log the next rock as a hit that wasn't timed. It teaches the ice
    //! nothing, and a split waiting to be logged is dropped.
    //! @return as addSplit(), or null if the end has no rocks left
    function logHit() as Symbol? {
        var marks = _table.marks().slice(0, null);
        var outcome = _game.logHit();
        if (outcome != null) {
            _marksBeforeLastRock = marks;
            cancelTimer();
            changed();
        }
        return outcome;
    }

    //! Pass over the next rock: it wasn't timed. A split waiting to be
    //! logged is dropped with it.
    //! @return as addSplit(), or null if the end has no rocks left
    function skipRock() as Symbol? {
        var outcome = _game.skipRock();
        if (outcome != null) {
            _splitLogged = true;
            changed();
        }
        return outcome;
    }

    //! Take back the last rock of this end and what it taught the ice; a
    //! timed rock's split can then be logged again
    //! @return false if this end has no rock to take back
    function undo() as Boolean {
        var rock = _game.undo();
        if (rock == null) {
            return false;
        }
        var marks = _marksBeforeLastRock;
        if (marks != null) {
            _table = new SplitTable(marks);
            saveMarks();
            _marksBeforeLastRock = null;
        }
        _startedAt = 0;
        _split = rock[Game.SPLIT];
        _splitLogged = false;
        _loggedPosition = -1;
        changed();
        return true;
    }

    //! Mark one of the wearer's own rocks this end Game.MADE or
    //! Game.MISSED, or Game.NO_SCORE to pass over it
    function markMine(slot as Number, result as Number) as Void {
        _game.markMine(slot, result);
        changed();
    }

    //! The wearer's position changed in the settings: skip their rocks
    function setMyPosition(position as Number) as Void {
        _game.setMyPosition(position);
        changed();
    }

    //! Mixed doubles: who throws this end's first and last rocks
    function setFirstThrower(player as Number) as Void {
        _game.setFirstThrower(player);
        changed();
    }

    //! The final score, entered after the game
    function setFinalScore(us as Number, them as Number) as Void {
        _game.setFinalScore(us, them);
        changed();
    }

    // ---------------------------------------------------------------- the ice

    //! Forget one thrower's ice marks (see Game.thrower), say someone whose
    //! splits are off today; the ice is learned again from the rest. It
    //! can't be undone, so undo no longer restores marks.
    function forgetMarks(thrower as Number) as Void {
        _table.forget(thrower);
        saveMarks();
        _marksBeforeLastRock = null;
    }

    //! Forget every ice mark: back to the starting ice
    function resetIce() as Void {
        _table.reset();
        Application.Storage.deleteValue(ICE_KEY);
        Application.Storage.deleteValue(OLD_ICE_KEY);
    }

    //! The remembered ice marks, moving any saved before the back 8 and
    //! back 12 over to today's positions
    private function loadMarks() {
        var marks = Application.Storage.getValue(ICE_KEY);
        var old = Application.Storage.getValue(OLD_ICE_KEY);
        if (marks == null && old != null) {
            marks = SplitTable.fromOldMarks(old);
            Application.Storage.setValue(ICE_KEY, marks);
            Application.Storage.deleteValue(OLD_ICE_KEY);
        }
        return marks;
    }

    private function saveMarks() as Void {
        Application.Storage.setValue(ICE_KEY, _table.marks());
    }

    // ---------------------------------------------------------------- storage

    //! The wearer's shots from every saved game (see Accuracy)
    function myAccuracy() as Array<Array<Number> > {
        return Accuracy.valid(Application.Storage.getValue(ACCURACY_KEY));
    }

    //! The end of a recent game that closed before it was saved, or 0
    function savedGameEnd() as Number {
        var saved = Application.Storage.getValue(GAME_KEY);
        if (!(saved instanceof Dictionary)) {
            return 0;
        }
        var time = saved.get("time");
        if (!(time instanceof Number) || Time.now().value() - time > RESUME_WITHIN) {
            return 0;
        }
        var game = new Game();
        return game.restore(saved.get("game")) ? game.end() : 0;
    }

    //! Pick the saved game up again: the next onStart() carries it on
    function resumeSavedGame() as Void {
        var saved = Application.Storage.getValue(GAME_KEY) as Dictionary;
        _game.restore(saved.get("game"));
    }

    //! Forget a saved game in favour of a new one
    function forgetSavedGame() as Void {
        Application.Storage.deleteValue(GAME_KEY);
    }

    //! After any change to the game: bring the activity up to date and save
    //! the game
    private function changed() as Void {
        var fields = _fields;
        if (fields != null) {
            fields.update(_game);
        }
        if (_game.end() > 0) {
            Application.Storage.setValue(GAME_KEY, {"game" => _game.save(), "time" => Time.now().value()});
        }
    }
}

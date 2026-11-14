import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! The watch's buttons, as Controls keys during a game (see Controls). Before
//! a game, Start begins it and holding Up opens the settings. The screen is
//! ignored during a game: a sweeping arm mustn't start or stop the timer.
class GameDelegate extends WatchUi.BehaviorDelegate {
    // Each button's key during a game
    private const KEYS = {
        WatchUi.KEY_START => :start,
        WatchUi.KEY_ENTER => :start,
        WatchUi.KEY_LAP => :back,
        WatchUi.KEY_ESC => :back,
        WatchUi.KEY_UP => :up,
        WatchUi.KEY_DOWN => :down,
    };

    private var _game as GameView;

    function initialize(game as GameView) {
        BehaviorDelegate.initialize();
        _game = game;
    }

    function onKey(event as WatchUi.KeyEvent) as Boolean {
        var button = event.getKey();
        logInput("onKey " + button + " type " + event.getType());
        var key = KEYS.get(button);
        if (key == null) {
            return false;
        }
        if (_game.isEcho(button)) {
            logInput("  ignored");
            return true;
        }
        if (_game.isSessionRecording()) {
            _game.press(key as Symbol);
            return true;
        }
        if (key == :start) {
            _game.start();
            return true;
        }
        // Back only leaves the app with no game under way: Garmin cuts off
        // an app's activity when it goes back to the watch face
        return key == :back && _game.isSessionActive();
    }

    //! Holding Up: a hit during a game, the settings before one
    function onMenu() as Boolean {
        logInput("onMenu");
        if (_game.isEcho(WatchUi.KEY_MENU)) {
            return true;
        }
        if (_game.isSessionRecording()) {
            _game.press(:holdUp);
        } else if (!_game.isSessionActive()) {
            _game.showSettings();
        }
        return true;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        return _game.isSessionRecording();
    }

    //! Holding the screen during a game places the split to log it
    function onHold(event as WatchUi.ClickEvent) as Boolean {
        logInput("onHold");
        if (!_game.isSessionRecording()) {
            return false;
        }
        _game.press(:holdScreen);
        return true;
    }
}

//! Every button event with its time, in the simulator's output (debug builds)
(:debug)
function logInput(event as String) as Void {
    System.println(System.getTimer() + " " + event);
}

(:release)
function logInput(event as String) as Void {
}

//! The game screen. After each timed rock: where it stopped (on the sheet).
//! Once the wearer's own rocks are thrown, whether each was made (if
//! that's on); at
//! the end of an end, the end's score if that's on, then (mixed doubles)
//! who throws first in the next end. After the game, its final score.
class GameView extends WatchUi.View {
    // Redraws while the split runs, and once a second otherwise (the clock)
    private const TICK_MS = 100;
    private const TICKS_A_SECOND = 10;

    private var _session as GameSession = new GameSession();
    private var _sheet as SheetFace?;
    private var _ticker as Timer.Timer = new Timer.Timer();
    private var _ticks as Number = 0;
    // The stop position being chosen for the last split, or -1 when none is
    private var _placing as Number = -1;
    // What logging the last rock did to the game
    private var _outcome as Symbol? = null;
    // The wearer's rock whose score is being asked for, and whether the
    // end is being finished early
    private var _scoringSlot as Number = -1;
    private var _scoringEndOver as Boolean = false;
    // Our side of the final score while theirs is asked for, and what
    // follows: :save, :menu (the game menu again) or :none
    private var _finalUs as Number = 0;
    private var _finalThen as Symbol = :none;
    // The end is over but its score hasn't been asked for yet
    private var _endPending as Boolean = false;

    function initialize() {
        View.initialize();
    }

    public function onLayout(dc as Dc) as Void {
        _sheet = new SheetFace();
        startDemo();
        startVideo();
    }

    // The video build (make video) plays a scripted game by pressing the
    // same buttons a player would, for the store's demo video
    (:video) private var _videoTimer as Timer.Timer? = null;
    (:video) private var _videoStep as Number = 0;

    //! Each step: how long to wait (ms), then the button (or answer)
    (:video)
    private function videoScript() as Array<Array> {
        return [
            [1500, :start], [3800, :start],              // the lead's first rock: 3.80
            [1500, :up], [1200, :down], [1200, :start],  // place it a ring deeper, log it
            [1600, :holdUp],                             // the lead's second: a hit
            [2200, :made], [1600, :missed],              // my two rocks (I play second)
            [1500, :start], [3950, :start],              // the vice's first rock
            [1500, :up], [1200, :start],                 // log it where predicted
            [1600, :down], [4000, :none],                // the team list
        ] as Array<Array>;
    }

    (:video)
    private function startVideo() as Void {
        if (_videoTimer != null) {
            return;
        }
        _session.setMyPosition(1);
        _videoTimer = new Timer.Timer();
        waitToRecord();
    }

    // The simulator may still be closing the last app's activity: start
    // the script once this one records
    (:video)
    function waitToRecord() as Void {
        _session.onStart();
        if (_session.isSessionRecording()) {
            WatchUi.requestUpdate();
            nextVideoStep();
        } else {
            (_videoTimer as Timer.Timer).start(method(:waitToRecord), 500, false);
        }
    }

    (:novideo)
    private function startVideo() as Void {
    }

    (:video)
    private function nextVideoStep() as Void {
        var script = videoScript();
        if (_videoStep >= script.size()) {
            return;
        }
        var timer = _videoTimer as Timer.Timer;
        timer.start(method(:playVideoStep), script[_videoStep][0] as Number, false);
    }

    (:video)
    function playVideoStep() as Void {
        var key = videoScript()[_videoStep][1] as Symbol;
        _videoStep++;
        if (key == :made || key == :missed) {
            // Answer the open "My rock" question as a player would
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            onMyShot(key == :made ? Game.MADE : Game.MISSED);
        } else if (key != :none) {
            press(key);
        }
        nextVideoStep();
    }

    // The demo build (make demo) sets a game up by itself, for checking the
    // screens on every watch and for store screenshots; other builds leave
    // it out (monkey.jungle excludes :demo)
    (:demo) private var _demoTimer as Timer.Timer? = null;

    (:demo)
    private function startDemo() as Void {
        if (_demoTimer != null) {
            return;
        }
        _session.onStart();
        // The wearer plays second: the lead's two rocks are logged, the
        // wearer's two are marked, and the vice's first is being placed
        _session.setMyPosition(1);
        _session.demoLog(3780, SplitTable.BUTTON);
        _session.demoLog(3870, 6);
        _session.markMine(2, Game.MADE);
        _session.markMine(3, Game.MISSED);
        _session.demoSplit(3840, 160);
        _placing = _session.getStopwatchEstimate();
        // Then the team list (tools/screens_all.sh captures both)
        var timer = new Timer.Timer();
        _demoTimer = timer;
        timer.start(method(:showStats), 10000, false);
        retryDemoRecording();
    }

    // The simulator can still be closing the last app's activity: try again
    // every half second (one timer: apps get only a few) until this records
    (:demo) private var _demoRetry as Timer.Timer? = null;
    (:demo) private var _demoTries as Number = 0;

    (:demo)
    function retryDemoRecording() as Void {
        if (_session.isSessionRecording() || _demoTries >= 20) {
            return;
        }
        _demoTries++;
        _session.onStart();
        var retry = _demoRetry;
        if (retry == null) {
            retry = new Timer.Timer();
            _demoRetry = retry;
        }
        retry.start(method(:retryDemoRecording), 500, false);
        WatchUi.requestUpdate();
    }

    (:nodemo)
    private function startDemo() as Void {
    }

    private var _keys as KeyFilter = new KeyFilter();

    public function isEcho(key as Number) as Boolean {
        return _keys.isEcho(key, System.getTimer());
    }

    // The redraw timer only runs while this screen shows. Left running
    // under a menu it asked for a redraw ten times a second (this view's
    // last draw never got newer), and the menu stuttered under Up/Down.
    public function onShow() as Void {
        _keys.shown(System.getTimer());
        _ticker.start(method(:onTick), TICK_MS, true);
    }

    public function onHide() as Void {
        _ticker.stop();
    }

    public function isSessionRecording() as Boolean {
        return _session.isSessionRecording();
    }

    public function isSessionActive() as Boolean {
        return _session.isSessionActive();
    }

    //! Start (or resume) the game, first offering to continue a game that
    //! closed before it was saved
    public function start() as Void {
        if (isSessionActive()) {
            resume(true);
            return;
        }
        var savedEnd = _session.savedGameEnd();
        if (savedEnd > 0) {
            WatchUi.pushView(Menus.resume(savedEnd), new AnswerDelegate(method(:onResumeAnswer)), WatchUi.SLIDE_UP);
            return;
        }
        newGame();
    }

    function onResumeAnswer(answer as Object?) as Void {
        if (answer == :continue) {
            _session.resumeSavedGame();
            _endPending = _session.getGame().endComplete();
            resume(true);
        } else if (answer == :new) {
            _session.forgetSavedGame();
            newGame();
        }
    }

    //! A new game; in mixed doubles, who throws first comes before the
    //! wearer's first rock can be up
    private function newGame() as Void {
        var doubles = _session.getGame().isDoubles();
        resume(!doubles);
        if (doubles) {
            askFirstThrower();
        }
    }

    //! Back to the game, asking about the wearer's rocks that are up if
    //! `askMine`
    private function resume(askMine as Boolean) as Void {
        _session.onStart();
        wake();
        if (askMine) {
            askMyScores(false);
        } else {
            checkEnd();
        }
        WatchUi.requestUpdate();
    }

    //! A button during a game
    //! @param key :start, :back, :up, :down, :holdUp or :holdScreen
    public function press(key as Symbol) as Void {
        var state = _session.isStopwatchRunning() ? Controls.TIMING
            : (_placing >= 0 ? Controls.PLACING : Controls.READY);
        var action = Controls.action(state, key);
        logInput("  state " + state + " " + key + " -> " + action);
        if (action == :startTimer) {
            beginTiming();
        } else if (action == :stopTimer) {
            _session.stopTimer();
            buzz([new Attention.VibeProfile(60, 80)]);
        } else if (action == :unplace) {
            _placing = -1;
        } else if (action == :cancelTimer) {
            _placing = -1;
            _session.cancelTimer();
            buzz([new Attention.VibeProfile(40, 50), new Attention.VibeProfile(0, 80), new Attention.VibeProfile(40, 50)]);
        } else if (action == :place) {
            placeRock();
        } else if (action == :deeper || action == :shorter) {
            var position = _placing + (action == :deeper ? 1 : -1);
            if (position >= 0 && position < SplitTable.POSITIONS) {
                _placing = position;
            }
        } else if (action == :log) {
            logPlaced();
        } else if (action == :logAndHit) {
            if (logPlaced()) {
                markHit();
            }
        } else if (action == :cancelAndHit) {
            _session.cancelTimer();
            markHit();
        } else if (action == :hit) {
            markHit();
        } else if (action == :pause) {
            pause();
        } else if (action == :stats) {
            showStats();
        }
        wake();
        WatchUi.requestUpdate();
    }

    //! The back line: a short buzz confirms it without looking
    private function beginTiming() as Void {
        _session.startTimer();
        buzz([new Attention.VibeProfile(60, 80)]);
    }

    //! Put the last timed rock on its predicted spot, to be moved with
    //! Up/Down. Does nothing with no split, while timing, or once it's logged.
    private function placeRock() as Void {
        if (_session.canMark()) {
            _placing = _session.getStopwatchEstimate();
        }
    }

    //! Log the rock being placed where it's shown, with a short buzz
    //! @return true if the end goes on (another rock can be logged now)
    private function logPlaced() as Boolean {
        var position = _placing;
        _placing = -1;
        _outcome = _session.addSplit(position);
        if (_outcome == null) {
            return true;
        }
        buzz([new Attention.VibeProfile(40, 60)]);
        var goesOn = _outcome == :rock;
        finishRock();
        return goesOn;
    }

    //! The next rock is a hit, not timed: logged for its thrower with one
    //! long buzz
    private function markHit() as Void {
        _placing = -1;
        _outcome = _session.logHit();
        if (_outcome != null) {
            buzz([new Attention.VibeProfile(70, 300)]);
            finishRock();
        }
    }

    private function finishRock() as Void {
        var outcome = _outcome;
        _outcome = null;
        _endPending = outcome == :endComplete || outcome == :gameOver;
        askMyScores(false);
    }

    //! Ask whether each of the wearer's rocks that are up was made, one at
    //! a time (Back passes over one), then finish the end if it's over. The
    //! question opens as the rock comes up, and waits while it's thrown.
    //! @param endOver true when the end is being finished before its last
    //!     rock: then its score is asked for next
    private function askMyScores(endOver as Boolean) as Void {
        _scoringEndOver = endOver;
        if (_scoringSlot >= 0) {
            // Already asking: the answer carries on from there
            return;
        }
        var game = _session.getGame();
        if (Settings.isOn(Settings.SCORE_MINE) && game.end() > 0) {
            var due = game.dueMine();
            if (due.size() > 0) {
                _scoringSlot = due[0];
                WatchUi.pushView(Menus.myShot(game, _scoringSlot), new AnswerDelegate(method(:onMyShot)),
                    WatchUi.SLIDE_UP);
                return;
            }
        }
        if (endOver) {
            askEndScore();
        } else {
            checkEnd();
        }
    }

    function onMyShot(answer as Object?) as Void {
        var slot = _scoringSlot;
        _scoringSlot = -1;
        _session.markMine(slot, answer != null ? answer as Number : Game.NO_SCORE);
        askMyScores(_scoringEndOver);
        WatchUi.requestUpdate();
    }

    //! The game's final score: ours, then theirs (Back skips it), then
    //! `then`: :save saves the game, :menu reopens the game menu
    private function askFinalScore(then as Symbol) as Void {
        _finalThen = then;
        var totals = _session.getGame().totals();
        WatchUi.pushView(Menus.points("Our score?", totals[0]), new AnswerDelegate(method(:onFinalUs)),
            WatchUi.SLIDE_UP);
    }

    function onFinalUs(answer as Object?) as Void {
        if (answer == null) {
            afterFinalScore();
            return;
        }
        _finalUs = answer as Number;
        var totals = _session.getGame().totals();
        WatchUi.pushView(Menus.points("Their score?", totals[1]), new AnswerDelegate(method(:onFinalThem)),
            WatchUi.SLIDE_UP);
    }

    function onFinalThem(answer as Object?) as Void {
        if (answer != null) {
            _session.setFinalScore(_finalUs, answer as Number);
        }
        afterFinalScore();
    }

    private function afterFinalScore() as Void {
        if (_finalThen == :save) {
            _session.resetSession(true);
        } else if (_finalThen == :menu) {
            pause();
        }
        WatchUi.requestUpdate();
    }

    //! Pause the game and open its menu
    public function pause() as Void {
        _session.onStop();
        _placing = -1;
        WatchUi.pushView(Menus.game(_session.getGame()), new AnswerDelegate(method(:onGameMenuAnswer)), WatchUi.SLIDE_UP);
        WatchUi.requestUpdate();
    }

    function onGameMenuAnswer(answer as Object?) as Void {
        if (answer == :resume_game) {
            resume(true);
        } else if (answer == :undo) {
            _session.undo();
            resume(true);
            // A timed rock's split goes back on the sheet to be marked again
            placeRock();
        } else if (answer == :skip_rock) {
            var outcome = _session.skipRock();
            _endPending = outcome == :endComplete || outcome == :gameOver;
            resume(true);
        } else if (answer == :first_rock) {
            askFirstThrower();
        } else if (answer == :next_end) {
            // For when rocks weren't logged, or to finish early
            _session.onStart();
            wake();
            askMyScores(true);
        } else if (answer == :final_score) {
            askFinalScore(:menu);
        } else if (answer == :save) {
            // A game saved without a score asks for its final score first
            if (_session.getGame().hasScore()) {
                _session.resetSession(true);
            } else {
                askFinalScore(:save);
            }
        } else if (answer == :discard) {
            WatchUi.pushView(new WatchUi.Confirmation("Really discard?"), new YesDelegate(method(:discard)),
                WatchUi.SLIDE_IMMEDIATE);
        } else if (answer == :settings) {
            showSettings();
        } else if (answer == :reset_ice) {
            WatchUi.pushView(Menus.ice(_session.getTable()), new AnswerDelegate(method(:onIceAnswer)),
                WatchUi.SLIDE_UP);
        }
        WatchUi.requestUpdate();
    }

    //! Forget every ice mark, or one thrower's, then back to the game menu
    //! (Back keeps them all)
    function onIceAnswer(answer as Object?) as Void {
        if (answer == :all) {
            _session.resetIce();
        } else if (answer instanceof Number) {
            _session.forgetMarks(answer as Number);
        }
        pause();
    }

    public function showSettings() as Void {
        var sync = _session.practiceSync();
        WatchUi.pushView(Menus.settings(sync), new SettingsDelegate(method(:onMyPosition), sync), WatchUi.SLIDE_UP);
    }

    //! Skipping the wearer's rocks can finish the end; its score is asked
    //! for when the game resumes
    function onMyPosition(position as Number) as Void {
        _session.setMyPosition(position);
        if (isSessionActive() && _session.getGame().endComplete()) {
            _endPending = true;
        }
    }

    public function discard() as Void {
        _session.resetSession(false);
        _placing = -1;
        _endPending = false;
        WatchUi.requestUpdate();
    }

    //! A long double buzz when the end is over, then its score
    private function checkEnd() as Void {
        if (!_endPending) {
            return;
        }
        _endPending = false;
        buzz([new Attention.VibeProfile(80, 250), new Attention.VibeProfile(0, 120),
            new Attention.VibeProfile(80, 250)]);
        wake();
        askEndScore();
    }

    //! The end is over: record its score (if line scores are on) and move on
    private function askEndScore() as Void {
        if (Settings.isOn(Settings.LINE_SCORE)) {
            WatchUi.pushView(Menus.endScore(_session.getGame()), new AnswerDelegate(method(:onEndScore)), WatchUi.SLIDE_UP);
        } else {
            onEndScore(null);
        }
    }

    //! The next end starts (asking who throws first, in mixed doubles, then
    //! about the wearer's rocks if they throw first);
    //! after the last end the game pauses on its menu to be saved, first
    //! asking for the final score if no ends were scored
    function onEndScore(answer as Object?) as Void {
        if (!_session.completeEnd(answer as Number?)) {
            pause();
            if (!_session.getGame().hasScore()) {
                askFinalScore(:none);
            }
        } else if (_session.getGame().isDoubles()) {
            askFirstThrower();
        } else {
            askMyScores(false);
        }
        WatchUi.requestUpdate();
    }

    private function askFirstThrower() as Void {
        WatchUi.pushView(Menus.firstThrower(_session.getGame()), new AnswerDelegate(method(:onFirstThrower)),
            WatchUi.SLIDE_UP);
    }

    function onFirstThrower(answer as Object?) as Void {
        if (answer != null) {
            _session.setFirstThrower(answer as Number);
        }
        if (_session.isSessionRecording()) {
            askMyScores(false);
        }
        WatchUi.requestUpdate();
    }

    public function showStats() as Void {
        WatchUi.pushView(Menus.stats(_session.getGame(), _session.myAccuracy()), new InfoDelegate(), WatchUi.SLIDE_UP);
    }

    public function onUpdate(dc as Dc) as Void {
        var sheet = _sheet;
        if (sheet == null) {
            return;
        }
        var recording = isSessionRecording();
        var running = _session.isStopwatchRunning();
        var game = _session.getGame();
        var table = _session.getTable();
        var split = _session.getStopwatchValue();

        // The big text: the prompt before a game, else the split, or HIT
        // after an untimed hit
        var big = "";
        var dim = false;
        if (!recording) {
            var savedEnd = isSessionActive() ? 0 : _session.savedGameEnd();
            big = isSessionActive() ? "Press Start\nto resume"
                : (savedEnd > 0 ? "Press Start to\ncontinue end " + savedEnd : "Press Start\nto begin");
        } else {
            var last = game.lastRock();
            if (split == 0 && last != null && last[Game.SPLIT] == 0 && last[Game.END] == game.end() && game.rocks() > 0) {
                big = "HIT";
            } else {
                big = Labels.split(split);
                dim = split == 0;
            }
        }

        // The rock on the sheet: sliding with the split while timing, on
        // its spot while placing, else where the last split predicts
        var rockFeet = null;
        var position = -1;
        if (recording && _placing >= 0) {
            position = _placing;
            rockFeet = (SplitTable.POSITION_FEET[position] as Number).toFloat();
        } else if (recording && split > 0) {
            // Once logged, the rock sits where it was logged, not where the
            // split predicted
            position = _session.getShownPosition();
            rockFeet = running ? _session.getStopwatchFeet() : (SplitTable.POSITION_FEET[position] as Number).toFloat();
        }

        var footer = "";
        if (recording && _placing >= 0) {
            footer = "Start logs it";
        } else if (recording && _session.canMark()) {
            footer = "Up to log it";
        } else if (game.hasScore()) {
            var totals = game.totals();
            footer = "US " + totals[0] + " - " + totals[1] + " THEM";
        }
        var slots = new Array<Number>[game.rocksPerEnd()];
        for (var i = 0; i < slots.size(); ++i) {
            slots[i] = game.slotState(i);
        }
        var button = table.splitTime(SplitTable.BUTTON);
        sheet.draw(dc, {
            :big => big,
            :prompt => !recording,
            :dim => dim,
            :placing => recording && _placing >= 0,
            :running => running,
            :rockFeet => rockFeet,
            :positionName => position >= 0 ? Labels.STOP_POSITIONS[position] as String : "",
            :end => game.end(),
            :slots => slots,
            :thrower => Labels.player(game.format(), game.nextPlayer()).toUpper(),
            :button => button,
            :buttonDelta => button - table.defaultSplit(SplitTable.BUTTON),
            :strokes => _session.endStrokes(),
            :footer => footer,
        });
    }

    //! The running split needs every tick; the rest of the screen changes
    //! at most once a second
    function onTick() as Void {
        _ticks = (_ticks + 1) % TICKS_A_SECOND;
        if (_ticks == 0 || _session.isStopwatchRunning()) {
            WatchUi.requestUpdate();
        }
    }

    //! The app's settings changed in Garmin Connect: the practice key may now
    //! be there, so send anything waiting
    function settingsChanged() as Void {
        _session.practiceSync().send();
        WatchUi.requestUpdate();
    }

    //! The app is closing: pause the game, which is saved as it goes
    function pauseForExit() as Void {
        _session.onStop();
    }

    //! Turn the screen on for the watch's display timeout. The FR265's
    //! AMOLED screen goes dark quickly during an activity, and the watch
    //! refuses (throws) if an app keeps it lit too long, so this only wakes it.
    private function wake() as Void {
        if (Attention has :backlight) {
            try {
                Attention.backlight(true);
            } catch (e) {
                // Lit too long already: the next press wakes it
            }
        }
    }

    private function buzz(pattern as Array<Attention.VibeProfile>) as Void {
        if (Attention has :vibrate) {
            Attention.vibrate(pattern);
        }
    }
}

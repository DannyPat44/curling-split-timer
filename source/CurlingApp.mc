import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! The app: one screen, the game. When the app closes, the game is paused;
//! it's saved as it goes, so it can be picked up again.
class CurlingApp extends Application.AppBase {
    private var _game as GameView? = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var game = new GameView();
        _game = game;
        return [game, new GameDelegate(game)];
    }

    function onStop(state as Dictionary?) as Void {
        var game = _game;
        if (game != null) {
            game.pauseForExit();
        }
    }
}

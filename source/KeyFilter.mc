import Toybox.Lang;

//! Drops key events that aren't new presses: the tail of the press that
//! just closed a menu (which would otherwise also act on the game screen,
//! such as starting the timer after choosing the end score), and the same
//! button again faster than anyone presses it.
class KeyFilter {
    static const MENU_ECHO_MS = 300;
    static const REPEAT_MS = 120;

    private var _shownAt as Number = -MENU_ECHO_MS;
    private var _lastKey as Number = -1;
    private var _lastKeyAt as Number = 0;

    function initialize() {
    }

    //! The game screen is showing again (a menu closed) at `now` ms
    function shown(now as Number) as Void {
        _shownAt = now;
    }

    //! @return true to ignore this key event
    function isEcho(key as Number, now as Number) as Boolean {
        var echo = now - _shownAt < MENU_ECHO_MS || (key == _lastKey && now - _lastKeyAt < REPEAT_MS);
        _lastKey = key;
        _lastKeyAt = now;
        return echo;
    }
}

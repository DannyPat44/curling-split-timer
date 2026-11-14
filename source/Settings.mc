import Toybox.Application;
import Toybox.Lang;

//! Choices kept on the watch between games: the game's format, the
//! wearer's position (whose rocks are skipped) and the steps after a rock
module Settings {
    const FORMAT = "format";
    // Asking whether the wearer made each of their shots is on until
    // switched off; a new key, since the old one scored teammates' rocks
    const SCORE_MINE = "scoreMine";
    const LINE_SCORE = "endScore";
    const MY_POSITION = "myPosition";

    //! Marking the wearer's shots is on until switched off; every other
    //! step is off until switched on
    function isOn(key as String) as Boolean {
        var value = Application.Storage.getValue(key);
        return value == null ? key.equals(SCORE_MINE) : value == true;
    }

    function toggle(key as String) as Boolean {
        var on = !isOn(key);
        Application.Storage.setValue(key, on);
        return on;
    }

    //! Game.FOURS or Game.DOUBLES, for the next game
    function format() as Number {
        return Application.Storage.getValue(FORMAT) == Game.DOUBLES ? Game.DOUBLES : Game.FOURS;
    }

    function nextFormat() as Number {
        var format = format() == Game.DOUBLES ? Game.FOURS : Game.DOUBLES;
        Application.Storage.setValue(FORMAT, format);
        return format;
    }

    //! The wearer's position in fours, 0-3 (lead to skip), or -1 to time
    //! every rock
    function myPosition() as Number {
        var value = Application.Storage.getValue(MY_POSITION);
        return value instanceof Number && value >= 0 && value < 4 ? value : -1;
    }

    //! Step to the next position: none, lead, second, vice, skip, none...
    function nextPosition() as Number {
        var position = myPosition() + 1;
        if (position >= 4) {
            position = -1;
        }
        Application.Storage.setValue(MY_POSITION, position);
        return position;
    }
}

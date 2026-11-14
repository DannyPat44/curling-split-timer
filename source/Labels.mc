import Toybox.Lang;

//! Names and formats shown on screen
module Labels {
    const PLAYERS = ["Lead", "Second", "Vice", "Skip"];
    // Indexes match Game.ME and Game.PARTNER
    const DOUBLES_PLAYERS = ["Me", "Partner"];
    const FORMATS = ["Fours", "Mixed doubles"];

    //! A player's name in a game's format
    function player(format as Number, player as Number) as String {
        return (format == Game.DOUBLES ? DOUBLES_PLAYERS[player] : PLAYERS[player]) as String;
    }

    // Indexes match SplitTable's positions: hogged, weights 1-12, then hack,
    // board and hit weight
    const STOP_POSITIONS = [
        "Hogged", "Guard, just past hog", "Guard", "Guard", "Guard, near house",
        "Top 12-foot", "Top 8-foot", "Top 4-foot", "Button", "Back 4-foot", "Back 8-foot",
        "Back 12-foot", "Through to hack", "To the boards", "Hit weight",
    ];

    //! Who threw an ice mark (see Game.thrower): "Lead", "Partner (doubles)",
    //! or "Earlier marks" for marks from before throwers were kept
    function thrower(thrower as Number) as String {
        if (thrower < 0) {
            return "Earlier marks";
        }
        if (thrower >= Game.DOUBLES_THROWERS) {
            return DOUBLES_PLAYERS[thrower - Game.DOUBLES_THROWERS] + " (doubles)";
        }
        return PLAYERS[thrower] as String;
    }

    //! The wearer's position, for the setting: "Lead", or "None" for -1
    function position(position as Number) as String {
        return position >= 0 ? PLAYERS[position] as String : "None";
    }

    //! A split in ms as seconds: "3.82"
    function split(ms as Number) as String {
        return (ms / 1000.0).format("%.2f");
    }

    //! An end's points: "Us 2", "Them 1" or "Blank"
    function endPoints(points as Number) as String {
        if (points > 0) {
            return "Us " + points;
        }
        return points < 0 ? "Them " + (-points) : "Blank";
    }

    //! A shot percentage, or a dash if nothing is scored
    function shots(percent as Number) as String {
        return percent >= 0 ? percent + "%" : "-";
    }
}

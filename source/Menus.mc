import Toybox.Lang;
import Toybox.WatchUi;

//! A menu whose answer goes back to the view: the chosen item's id, or null
//! when Back skips the question. The menu is closed before the answer is
//! handled, so the answer can open the next menu.
class AnswerDelegate extends WatchUi.Menu2InputDelegate {
    private var _answer as Method(answer as Object?) as Void;

    function initialize(answer as Method(answer as Object?) as Void) {
        Menu2InputDelegate.initialize();
        _answer = answer;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        _answer.invoke(item.getId());
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        _answer.invoke(null);
    }
}

//! A list to read, closed by selecting anything or Back
class InfoDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

//! The settings: each item's id is its Settings key. Toggles switch on
//! and off; Game and My position step through their choices, and the game
//! is told about a new position.
class SettingsDelegate extends WatchUi.Menu2InputDelegate {
    private var _onPosition as Method(position as Number) as Void;

    function initialize(onPosition as Method(position as Number) as Void) {
        Menu2InputDelegate.initialize();
        _onPosition = onPosition;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var key = item.getId() as String;
        if (key.equals(Settings.MY_POSITION)) {
            var position = Settings.nextPosition();
            item.setSubLabel(Menus.positionSubLabel(position));
            WatchUi.requestUpdate();
            _onPosition.invoke(position);
        } else if (key.equals(Settings.FORMAT)) {
            item.setSubLabel(Menus.formatSubLabel(Settings.nextFormat()));
            WatchUi.requestUpdate();
        } else {
            Settings.toggle(key);
        }
    }
}

//! "Really discard?": a yes runs `onYes`
class YesDelegate extends WatchUi.ConfirmationDelegate {
    private var _onYes as Method() as Void;

    function initialize(onYes as Method() as Void) {
        ConfirmationDelegate.initialize();
        _onYes = onYes;
    }

    function onResponse(answer as WatchUi.Confirm) as Boolean {
        if (answer == WatchUi.CONFIRM_YES) {
            _onYes.invoke();
        }
        return true;
    }
}

//! Builds the menus
module Menus {
    //! Whether one of the wearer's own rocks made the shot they set out to
    //! play, opened on Made it; Back passes over it
    function myShot(game as Game, slot as Number) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => "My rock " + game.mineNumber(slot) + "?", :focus => 0});
        menu.addItem(new WatchUi.MenuItem("Made it", "the shot I called", Game.MADE, null));
        menu.addItem(new WatchUi.MenuItem("Missed", null, Game.MISSED, null));
        return menu;
    }

    //! One side's final score, 0 to 20, opened on `focus`
    function points(title as String, focus as Number) as WatchUi.Menu2 {
        var most = 20;
        var menu = new WatchUi.Menu2({:title => title, :focus => focus < most ? focus : most});
        for (var points = 0; points <= most; ++points) {
            menu.addItem(new WatchUi.MenuItem(points.toString(), null, points, null));
        }
        return menu;
    }

    //! Who scored the end and how many, opened on Blank
    function endScore(game as Game) as WatchUi.Menu2 {
        var most = game.maxPoints();
        var menu = new WatchUi.Menu2({:title => "End " + game.end() + " score?", :focus => most});
        for (var points = most; points >= -most; --points) {
            menu.addItem(new WatchUi.MenuItem(Labels.endPoints(points), null, points, null));
        }
        return menu;
    }

    //! Mixed doubles: who throws this end's first and last rocks, opened on
    //! whoever did last end
    function firstThrower(game as Game) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => "End " + game.end() + ": first rock?",
            :focus => game.firstThrower() == Game.ME ? 0 : 1});
        menu.addItem(new WatchUi.MenuItem("Me", "I throw 1st and 5th", Game.ME, null));
        menu.addItem(new WatchUi.MenuItem("Partner", "I throw 2nd to 4th", Game.PARTNER, null));
        return menu;
    }

    //! Pick up a game that closed before it was saved, or start fresh
    function resume(end as Number) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => "Game in progress"});
        menu.addItem(new WatchUi.MenuItem("Continue", "from end " + end, :continue, null));
        menu.addItem(new WatchUi.MenuItem("New game", null, :new, null));
        return menu;
    }

    //! Back's menu while a game is paused
    function game(game as Game) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => "End " + game.end()});
        menu.addItem(new WatchUi.MenuItem("Resume", null, :resume_game, null));
        menu.addItem(new WatchUi.MenuItem("Settings", "game, position, scores", :settings, null));
        var rock = game.rocks() > 0 ? game.lastRock() : null;
        if (rock != null) {
            menu.addItem(new WatchUi.MenuItem("Undo last rock", rockLabel(rock), :undo, null));
        }
        if (!game.endComplete()) {
            menu.addItem(new WatchUi.MenuItem("Skip rock", Labels.player(game.format(), game.nextPlayer())
                + "'s, not timed", :skip_rock, null));
        }
        if (game.isDoubles() && game.rocks() == 0) {
            menu.addItem(new WatchUi.MenuItem("First rock", Labels.player(game.format(), game.firstThrower())
                + " throws 1st and 5th", :first_rock, null));
        }
        var last = game.end() >= Game.ENDS;
        menu.addItem(new WatchUi.MenuItem(last ? "Finish game" : "Next end",
            game.rocks() + " rocks logged this end", :next_end, null));
        var totals = game.totals();
        menu.addItem(new WatchUi.MenuItem("Final score", game.hasScore()
            ? "Us " + totals[0] + " - " + totals[1] + " Them" : "not set", :final_score, null));
        menu.addItem(new WatchUi.MenuItem("Save", null, :save, null));
        menu.addItem(new WatchUi.MenuItem("Discard", null, :discard, null));
        menu.addItem(new WatchUi.MenuItem("Reset ice", "forget marks", :reset_ice, null));
        return menu;
    }

    //! Which ice marks to forget: everyone's, or one thrower's (with how
    //! many marks each has)
    function ice(table as SplitTable) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => "Forget marks"});
        var marks = table.marks().size();
        menu.addItem(new WatchUi.MenuItem("All marks", marks + (marks == 1 ? " mark" : " marks") + ", back to 3.70",
            :all, null));
        var throwers = table.throwers();
        for (var i = 0; i < throwers.size(); ++i) {
            var count = throwers[i][1];
            menu.addItem(new WatchUi.MenuItem(Labels.thrower(throwers[i][0]),
                count + (count == 1 ? " mark" : " marks"), throwers[i][0], null));
        }
        return menu;
    }

    //! The settings. Game applies from the next game.
    function settings() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => "Settings"});
        menu.addItem(new WatchUi.MenuItem("Game", formatSubLabel(Settings.format()), Settings.FORMAT, null));
        menu.addItem(new WatchUi.MenuItem("My position", positionSubLabel(Settings.myPosition()),
            Settings.MY_POSITION, null));
        var states = {:enabled => "Made or missed", :disabled => "Off"};
        menu.addItem(new WatchUi.ToggleMenuItem("My shots", states, Settings.SCORE_MINE, Settings.isOn(Settings.SCORE_MINE), null));
        states = {:enabled => "Ask after each end", :disabled => "Off"};
        menu.addItem(new WatchUi.ToggleMenuItem("End score", states, Settings.LINE_SCORE, Settings.isOn(Settings.LINE_SCORE), null));
        return menu;
    }

    function formatSubLabel(format as Number) as String {
        return Labels.FORMATS[format] as String;
    }

    //! What My position does in fours: whose rocks are skipped
    function positionSubLabel(position as Number) as String {
        return position >= 0 ? "Fours: skip " + Labels.position(position) + "'s rocks" : "Fours: time every rock";
    }

    //! A logged rock in a line: "3.82s Button", or "Hit, not timed"
    function rockLabel(rock as Array<Number>) as String {
        if (rock[Game.SPLIT] <= 0) {
            return "Hit, not timed";
        }
        return Labels.split(rock[Game.SPLIT]) + "s  " + Labels.STOP_POSITIONS[rock[Game.POSITION]];
    }

    //! Down's list: the score, the wearer's shots made (this game and over
    //! recent games), each teammate's draw split, hits and shot
    //! percentage, then the last rocks
    //! @param accuracy the wearer's saved games (see Accuracy)
    function stats(game as Game, accuracy as Array<Array<Number> >) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => "Team"});
        if (game.hasScore()) {
            var totals = game.totals();
            var line = "final score";
            if (game.hasEndScores()) {
                line = "";
                for (var end = 1; end <= Game.ENDS; ++end) {
                    var points = game.endScore(end);
                    line += (end > 1 ? " " : "") + (points == null ? "·" : (points < 0 ? "-" + (-points) : points.toString()));
                }
            }
            menu.addItem(new WatchUi.MenuItem("Us " + totals[0] + " - " + totals[1] + " Them", line, :score, null));
        }
        if (game.mine() >= 0) {
            var shots = game.myShots();
            var recent = Accuracy.percent(accuracy, 10);
            var label = shots[1] > 0
                ? "Me  " + shots[0] + "/" + shots[1] + " made · " + Labels.shots(Game.madePercent(shots[0], shots[1]))
                : "Me";
            var sublabel = recent >= 0 ? "last 10 games " + recent + "%"
                : (shots[1] > 0 ? "this game" : "no shots marked yet");
            menu.addItem(new WatchUi.MenuItem(label, sublabel, :me, null));
        }
        for (var player = 0; player < game.players(); ++player) {
            if (player == game.mine()) {
                continue;
            }
            var split = game.averageSplit(player, 0);
            var shots = game.shotPercent(player);
            var label = Labels.player(game.format(), player) + "  " + (split > 0 ? Labels.split(split) + "s" : "-")
                + (shots >= 0 ? " · " + Labels.shots(shots) : "");
            var rocks = game.rockCount(player);
            var hits = game.hitCount(player);
            var sublabel = rocks + (rocks == 1 ? " rock" : " rocks") + (hits > 0 ? " · " + hits + (hits == 1 ? " hit" : " hits") : "");
            menu.addItem(new WatchUi.MenuItem(label, sublabel, player, null));
        }
        var history = game.history();
        for (var i = history.size() - 1; i >= 0; --i) {
            var rock = history[i];
            var detail = "End " + rock[Game.END] + " · " + Labels.player(game.format(), rock[Game.PLAYER]);
            if (rock[Game.SCORE] != Game.NO_SCORE) {
                detail += " · " + rock[Game.SCORE] + "/4";
            }
            menu.addItem(new WatchUi.MenuItem(rockLabel(rock), detail, "rock" + i, null));
        }
        return menu;
    }
}

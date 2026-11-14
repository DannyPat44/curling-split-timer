import Toybox.Lang;

//! The wearer's accuracy over time: each saved game's shots, kept on the
//! watch as [made, attempted], oldest first.
module Accuracy {
    const GAMES = 50;

    //! The games with one more added; a game with no shots marked isn't kept
    //! @param shots the game's Game.myShots()
    function add(games, shots as Array<Number>) as Array<Array<Number> > {
        var kept = valid(games);
        if (shots[1] <= 0) {
            return kept;
        }
        kept.add([shots[0], shots[1]] as Array<Number>);
        return kept.size() > GAMES ? kept.slice(kept.size() - GAMES, null) : kept;
    }

    //! The share of shots made over the last `last` games (0 for all of
    //! them), 0-100, or -1 with none
    function percent(games, last as Number) as Number {
        var kept = valid(games);
        var from = last > 0 && kept.size() > last ? kept.size() - last : 0;
        var made = 0;
        var attempted = 0;
        for (var i = from; i < kept.size(); ++i) {
            made += kept[i][0];
            attempted += kept[i][1];
        }
        return Game.madePercent(made, attempted);
    }

    //! Games kept on the watch, or none if what's stored isn't a list of them
    function valid(games) as Array<Array<Number> > {
        var kept = [] as Array<Array<Number> >;
        if (games instanceof Array) {
            for (var i = 0; i < games.size(); ++i) {
                var game = games[i];
                if (game instanceof Array && game.size() == 2 && game[0] instanceof Number
                        && game[1] instanceof Number) {
                    kept.add(game as Array<Number>);
                }
            }
        }
        return kept;
    }
}

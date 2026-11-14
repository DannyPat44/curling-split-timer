import Toybox.Lang;
import Toybox.Test;

(:test)
function accuracyOverRecentGames(logger as Logger) as Boolean {
    // [made, attempted]
    var games = Accuracy.add(null, [2, 4] as Array<Number>);     // 50%
    games = Accuracy.add(games, [0, 0] as Array<Number>);        // no shots marked: not kept
    games = Accuracy.add(games, [4, 4] as Array<Number>);        // 100%
    Test.assertEqual(games.size(), 2);
    Test.assertEqual(Accuracy.percent(games, 0), 75);
    Test.assertEqual(Accuracy.percent(games, 1), 100);
    Test.assertEqual(Accuracy.percent([], 10), -1);
    return true;
}

(:test)
function accuracyKeepsTheLastFiftyGames(logger as Logger) as Boolean {
    var games = [] as Array<Array<Number> >;
    for (var i = 0; i < Accuracy.GAMES + 5; ++i) {
        games = Accuracy.add(games, [i, 1] as Array<Number>);
    }
    Test.assertEqual(games.size(), Accuracy.GAMES);
    Test.assertEqual(games[0][0], 5);
    // Junk in storage reads as no games
    Test.assertEqual(Accuracy.valid("junk").size(), 0);
    Test.assertEqual(Accuracy.valid([[1, 2], "x", [3]]).size(), 1);
    return true;
}

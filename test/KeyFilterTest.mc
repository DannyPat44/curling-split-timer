import Toybox.Lang;
import Toybox.Test;

(:test)
function keyFilterDropsThePressThatClosedAMenu(logger as Logger) as Boolean {
    var keys = new KeyFilter();
    keys.shown(10000);
    Test.assert(keys.isEcho(4, 10050));
    Test.assert(!keys.isEcho(4, 10600));
    return true;
}

(:test)
function keyFilterDropsADoubledEvent(logger as Logger) as Boolean {
    var keys = new KeyFilter();
    Test.assert(!keys.isEcho(4, 5000));
    Test.assert(keys.isEcho(4, 5023));
    // A different button straight after is a real press
    Test.assert(!keys.isEcho(13, 5040));
    // So is the same button pressed again at human speed
    Test.assert(!keys.isEcho(13, 5300));
    return true;
}

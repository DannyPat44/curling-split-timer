import Toybox.Lang;
import Toybox.Test;

(:debug)
const HOG_AT = 1793023145123l;

(:test)
function sensorQueueKeepsThrowsInTheSitesRange(logger as Logger) as Boolean {
    var queue = new SensorQueue(null);
    Test.assert(queue.add("cst-a-1", HOG_AT, 3840));
    // Not throws the site would take: a timer left running, or a tap
    Test.assert(!queue.add("cst-a-2", HOG_AT, 9000));
    Test.assert(!queue.add("cst-a-3", HOG_AT, 900));
    Test.assertEqual(queue.waiting(), 1);
    var timing = queue.batch()[0];
    Test.assertEqual(timing["at_is"], "hog");
    Test.assertEqual(timing["at"], HOG_AT);
    Test.assert(((timing["short_s"] as Float) - 3.84).abs() < 0.001);
    var body = SensorQueue.body(queue.batch(), HOG_AT + 5000l);
    Test.assertEqual(body["sent_at"], HOG_AT + 5000l);
    return true;
}

(:test)
function sensorQueueSettlesWhatTheSiteAnswers(logger as Logger) as Boolean {
    var queue = new SensorQueue(null);
    queue.add("cst-a-1", HOG_AT, 3800);
    queue.add("cst-a-2", HOG_AT + 30000l, 3900);
    queue.add("cst-a-3", HOG_AT + 60000l, 4000);
    var sent = queue.batch();
    // Kept, refused for good, and one the answer doesn't mention
    queue.answered(200, {"timings" => [
        {"client_id" => "cst-a-1", "id" => "st_1", "session_id" => "ps_1"},
        {"client_id" => "cst-a-2", "error" => "no throw"},
    ]}, sent);
    Test.assertEqual(queue.waiting(), 1);
    Test.assertEqual(queue.batch()[0]["client_id"], "cst-a-3");
    Test.assertEqual(queue.sent(), 1);
    Test.assertEqual(queue.status(), SensorQueue.SENT);
    return true;
}

(:test)
function sensorQueueWaitsForThePhoneAndASession(logger as Logger) as Boolean {
    var queue = new SensorQueue(null);
    queue.add("cst-a-1", HOG_AT, 3800);
    // No phone (a Connect IQ error), then no practice session running
    queue.answered(-104, null, queue.batch());
    Test.assertEqual(queue.status(), SensorQueue.OFFLINE);
    Test.assertEqual(queue.waiting(), 1);
    queue.answered(409, {"timings" => [{"client_id" => "cst-a-1", "error" => "no session"}]}, queue.batch());
    Test.assertEqual(queue.status(), SensorQueue.NO_SESSION);
    Test.assertEqual(queue.waiting(), 1);
    // Half an hour on, nobody will place it
    queue.expire(HOG_AT + SensorQueue.KEEP_MS + 1000l);
    Test.assertEqual(queue.waiting(), 0);
    return true;
}

(:test)
function sensorQueueKeepsThrowsWhenTheKeyIsRefused(logger as Logger) as Boolean {
    var queue = new SensorQueue(null);
    queue.add("cst-a-1", HOG_AT, 3800);
    queue.answered(401, null, queue.batch());
    Test.assertEqual(queue.status(), SensorQueue.BAD_KEY);
    Test.assertEqual(queue.waiting(), 1);
    // A malformed request is dropped: sending it again won't help
    queue.answered(422, null, queue.batch());
    Test.assertEqual(queue.waiting(), 0);
    return true;
}

(:test)
function sensorQueueSendsAtMostFiftyAndSurvivesARestart(logger as Logger) as Boolean {
    var queue = new SensorQueue(null);
    for (var i = 0; i < 60; ++i) {
        queue.add("cst-a-" + i, HOG_AT + i * 20000l, 3800);
    }
    Test.assertEqual(queue.batch().size(), SensorQueue.MAX_BATCH);
    var restored = new SensorQueue(queue.save());
    Test.assertEqual(restored.waiting(), 60);
    Test.assertEqual(new SensorQueue("junk").waiting(), 0);
    return true;
}

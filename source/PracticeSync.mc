import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;

//! Sends each timed rock to curling.dimmit.net's practice page, through the
//! phone, when it's switched on in the app's settings in Garmin Connect (with
//! the player's sensor app key from curling.dimmit.net/practice). The key is
//! a setting on the watch: it is never in this code.
//!
//! The waiting timings (SensorQueue) are kept in storage, so a throw timed
//! while the phone is out of reach goes once it's back.
class PracticeSync {
    private const URL = "https://curling.dimmit.net/api/practice/sensors";
    // App settings (resources/settings): the key, and whether to send
    static const KEY_SETTING = "dimmitKey";
    static const ON_SETTING = "dimmitSync";
    private const STORE_KEY = "practiceSync";
    private const ID_KEY = "practiceSyncId";
    // How long to wait before trying again after no phone or no session
    private const RETRY_MS = 30000;

    private var _queue as SensorQueue;
    private var _inFlight as Array<Dictionary>? = null;
    private var _retry as Timer.Timer = new Timer.Timer();
    // The watch's clock in epoch ms against System.getTimer(), set once. Its
    // whole-second error is the same for every time sent, and the site
    // removes it with sent_at.
    private var _baseEpoch as Long;
    private var _baseTimer as Number;
    // Timings' ids: this install's own prefix, and a running count
    private var _prefix as String;
    private var _count as Number;

    function initialize() {
        _queue = new SensorQueue(Application.Storage.getValue(STORE_KEY));
        _baseEpoch = Time.now().value().toLong() * 1000l;
        _baseTimer = System.getTimer();
        var id = Application.Storage.getValue(ID_KEY);
        if (!(id instanceof Dictionary) || !(id.get("prefix") instanceof String)) {
            id = {"prefix" => (Math.rand() % 0x1000000).format("%06x"), "count" => 0};
        }
        _prefix = id.get("prefix") as String;
        var count = id.get("count");
        _count = count instanceof Number ? count : 0;
    }

    //! The sensor app key, if one is set and looks like one
    private function key() as String? {
        var value = Application.Properties.getValue(KEY_SETTING);
        if (!(value instanceof String)) {
            return null;
        }
        var key = trim(value);
        return key.length() > 4 && key.substring(0, 4).equals("csk_") ? key : null;
    }

    //! Switched on in the settings, with a key
    function isOn() as Boolean {
        return Application.Properties.getValue(ON_SETTING) == true && key() != null;
    }

    //! The setting is on, but there's no usable key
    function needsKey() as Boolean {
        return Application.Properties.getValue(ON_SETTING) == true && key() == null;
    }

    function queue() as SensorQueue {
        return _queue;
    }

    //! The watch's clock, epoch ms, at a System.getTimer() reading
    function epochAt(timer as Number) as Long {
        return _baseEpoch + (timer - _baseTimer);
    }

    //! A rock was timed: its split, and System.getTimer() at the hog line
    function timed(splitMs as Number, hogTimer as Number) as Void {
        logSync("timed " + splitMs + " ms, sending " + (isOn() ? "on" : "off"));
        if (!isOn()) {
            return;
        }
        _count++;
        Application.Storage.setValue(ID_KEY, {"prefix" => _prefix, "count" => _count});
        if (_queue.add("cst-" + _prefix + "-" + _count, epochAt(hogTimer), splitMs)) {
            save();
            send();
        }
    }

    //! Send what's waiting, if anything is and nothing is on its way
    function send() as Void {
        var key = key();
        if (_inFlight != null || key == null || !isOn()) {
            return;
        }
        var now = epochAt(System.getTimer());
        _queue.expire(now);
        if (_queue.waiting() == 0) {
            save();
            return;
        }
        var batch = _queue.batch();
        _inFlight = batch;
        try {
            Communications.makeWebRequest(URL, SensorQueue.body(batch, now), {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                    "Authorization" => "Bearer " + key,
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            }, method(:onResponse));
        } catch (e) {
            // No connection to ask: try again later
            onResponse(Communications.BLE_CONNECTION_UNAVAILABLE, null);
        }
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        logSync("answer " + code + " " + data);
        var sent = _inFlight;
        _inFlight = null;
        _queue.answered(code, data, sent != null ? sent : [] as Array<Dictionary>);
        save();
        if (_queue.waiting() == 0) {
            return;
        }
        var status = _queue.status();
        if (status == SensorQueue.SENT) {
            // More than one batch's worth was waiting
            send();
        } else if (status == SensorQueue.OFFLINE || status == SensorQueue.NO_SESSION) {
            _retry.start(method(:send), RETRY_MS, false);
        }
        // A refused key waits for the settings to change
    }

    private function save() as Void {
        Application.Storage.setValue(STORE_KEY, _queue.save());
    }

    private static function trim(s as String) as String {
        var chars = s.toCharArray();
        var from = 0;
        var to = chars.size();
        while (from < to && chars[from] <= ' ') {
            from++;
        }
        while (to > from && chars[to - 1] <= ' ') {
            to--;
        }
        return s.substring(from, to) as String;
    }
}

//! What the sync does, in the simulator's output (debug builds)
(:debug)
function logSync(event as String) as Void {
    System.println(System.getTimer() + " sync: " + event);
}

(:release)
function logSync(event as String) as Void {
}

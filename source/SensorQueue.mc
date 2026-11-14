import Toybox.Lang;

//! Timings waiting to go to curling.dimmit.net's sensor API
//! (docs: github.com/wdimmit/curling_stats, docs/sensor-app-api.md).
//!
//! Each timed rock becomes one timing: when it crossed the throwing hog line
//! (epoch ms, by the watch's clock) and its back-line-to-hog split. The site
//! matches it to the throw its cameras saw cross the hog line within 4 s,
//! in the practice session the key's owner has running. Timings wait here
//! until the site answers for them, so nothing is lost while the phone is out
//! of reach; a timing the site can't place (no session) is kept a while in
//! case one is started, then dropped.
//!
//! Plain logic: PracticeSync does the sending and the storage.
class SensorQueue {
    static const MAX_BATCH = 50;
    // The site's accepted split range, seconds
    static const MIN_SPLIT_MS = 1500;
    static const MAX_SPLIT_MS = 8000;
    // A timing nobody could place is dropped after this long
    static const KEEP_MS = 30 * 60 * 1000;

    // What the last answer from the site said
    static const IDLE = 0;      // nothing sent yet
    static const SENT = 1;      // everything sent was kept
    static const OFFLINE = 2;   // no phone, no network, or the site busy: will retry
    static const NO_SESSION = 3; // the site had no practice session running
    static const BAD_KEY = 4;   // the key is missing, unknown or revoked

    // Waiting timings, oldest first: {"client_id", "at", "at_is", "short_s"}
    private var _pending as Array<Dictionary> = [] as Array<Dictionary>;
    private var _status as Number = IDLE;
    private var _sent as Number = 0;

    //! @param saved the queue as saved by save(), or null
    function initialize(saved) {
        if (saved instanceof Dictionary) {
            var pending = saved.get("pending");
            if (pending instanceof Array) {
                for (var i = 0; i < pending.size(); ++i) {
                    if (pending[i] instanceof Dictionary) {
                        _pending.add(pending[i] as Dictionary);
                    }
                }
            }
            var sent = saved.get("sent");
            _sent = sent instanceof Number ? sent : 0;
        }
    }

    //! Queue a timed rock. A split outside the site's 1.5-8 s isn't a throw it
    //! would take, so it isn't queued.
    //! @param clientId unique per timing (the site keeps only the first of a repeat)
    //! @param hogAt when the rock crossed the hog line, epoch ms
    //! @return true if it was queued
    function add(clientId as String, hogAt as Long, splitMs as Number) as Boolean {
        if (splitMs < MIN_SPLIT_MS || splitMs > MAX_SPLIT_MS) {
            return false;
        }
        _pending.add({"client_id" => clientId, "at" => hogAt, "at_is" => "hog",
            "short_s" => Math.round(splitMs / 10.0) / 100.0});
        return true;
    }

    //! Drop timings older than KEEP_MS: the site won't place them now
    function expire(now as Long) as Void {
        var kept = [] as Array<Dictionary>;
        for (var i = 0; i < _pending.size(); ++i) {
            if (now - (_pending[i]["at"] as Long) <= KEEP_MS) {
                kept.add(_pending[i]);
            }
        }
        _pending = kept;
    }

    //! The next request's timings: up to MAX_BATCH, oldest first
    function batch() as Array<Dictionary> {
        return _pending.size() > MAX_BATCH ? _pending.slice(0, MAX_BATCH) : _pending.slice(0, null);
    }

    //! The request body for a batch
    //! @param now the watch's clock as the request goes, epoch ms, so the site
    //!     can correct for the watch's clock being off
    static function body(timings as Array<Dictionary>, now as Long) as Dictionary {
        return {"sent_at" => now, "timings" => timings};
    }

    //! The site's answer to a batch
    //! @param code the HTTP status, or a negative Connect IQ error (no phone,
    //!     timed out...)
    //! @param data the parsed JSON body, if any
    //! @param sent the batch that was sent
    function answered(code as Number, data, sent as Array<Dictionary>) as Void {
        if (code == 200) {
            // Each timing has an id (kept) or an error (it never will be):
            // either way it's settled. One with no entry stays to retry.
            var done = settled(data);
            var waiting = [] as Array<Dictionary>;
            for (var i = 0; i < _pending.size(); ++i) {
                var result = done.get(_pending[i]["client_id"]);
                if (result == null) {
                    waiting.add(_pending[i]);
                } else if (result == true) {
                    _sent++;
                }
            }
            _pending = waiting;
            _status = SENT;
        } else if (code == 409) {
            // No practice session was running: keep them all in case one
            // starts (expire() drops them later)
            _status = NO_SESSION;
        } else if (code == 401) {
            _status = BAD_KEY;
        } else if (code == 422 || code == 400) {
            // The request itself was wrong: sending it again won't help
            dropAll(sent);
            _status = SENT;
        } else {
            _status = OFFLINE;
        }
    }

    //! Which client_ids the site answered for: true kept, false refused
    private function settled(data) as Dictionary {
        var done = {} as Dictionary;
        if (!(data instanceof Dictionary)) {
            return done;
        }
        var timings = data.get("timings");
        if (!(timings instanceof Array)) {
            return done;
        }
        for (var i = 0; i < timings.size(); ++i) {
            var t = timings[i];
            if (t instanceof Dictionary && t.get("client_id") instanceof String) {
                done[t.get("client_id")] = t.get("id") != null;
            }
        }
        return done;
    }

    private function dropAll(sent as Array<Dictionary>) as Void {
        var ids = {} as Dictionary;
        for (var i = 0; i < sent.size(); ++i) {
            ids[sent[i]["client_id"]] = true;
        }
        var kept = [] as Array<Dictionary>;
        for (var i = 0; i < _pending.size(); ++i) {
            if (!ids.hasKey(_pending[i]["client_id"])) {
                kept.add(_pending[i]);
            }
        }
        _pending = kept;
    }

    function waiting() as Number {
        return _pending.size();
    }

    function sent() as Number {
        return _sent;
    }

    function status() as Number {
        return _status;
    }

    //! What to keep in storage
    function save() as Dictionary {
        return {"pending" => _pending, "sent" => _sent};
    }
}

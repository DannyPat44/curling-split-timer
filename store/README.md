# Connect IQ Store listing

Everything the store listing uses, and how to publish a new version.

- Listing: https://apps.garmin.com/apps/f6383df1-cbab-4387-85e0-7510400479f1
- Developer dashboard: https://apps.garmin.com/developer/dashboard (sign in with the Garmin account)
- Demo video: https://www.youtube.com/watch?v=r3viIWV5aks (`demo.mp4`)

## Assets in this folder

| File | Store field | Made with |
|---|---|---|
| `cover.png` | Cover image, 500x500, under 300 KB | `swift tools/rock_icon.swift store/cover.png 500` |
| `screenshot_sheet.jpg`, `screenshot_team.jpg` | Screen images, under 150 KB each (the store takes up to 5) | `make screens`, then crop a capture to the round screen |
| `demo.mp4` | Preview video, as a YouTube or Vimeo link (the store can't take the file) | `make video` |

## Listing text

**Title:** Curling Split Timer

**Tagline:** See where each rock will stop, timed right from your wrist.

**Description:**

```
Know where a rock is going to stop while it's still at the hog line.

A split tells you the weight, but "3.85" still has to become "guard or button?" in your head. Press Start at the back line and again at the hog line, and the watch shows the split and where that rock should stop, drawn on the sheet. Mark where it really stopped and the predictions learn the ice you're playing on.

It tracks your own game too: mark each of your shots made or missed, see your accuracy over your last 10 games on the watch, and find each game's shots made in Garmin Connect.

Built for club play. In competition, World Curling rules allow a stopwatch's time only, and in a club league your league's rules decide.

What it does:
- Splits with a buzz on each press, and a predicted stop from guards to hit weight
- Remembers the ice between games
- Fours and mixed doubles, with each rock credited to its thrower and each teammate's average draw split
- Untimed hits logged with one long press
- End-by-end or final score
- Sweeping strokes counted from the watch's motion sensor
- Undo, skip a rock, and pick a game back up if the app closes
- Saves a Garmin activity: heart rate, splits, strokes, score and shots made

For five-button Garmin watches: Forerunner 165, 255, 265, 570, 955, 965 and 970; fenix 7 series; epix Gen 2 and epix Pro; Enduro 3.

Free and open source (GPL 3.0): https://github.com/DannyPat44/curling-split-timer
```

The description should sell the app before it lists features: what a curler
gets from it first, then a short summary of what it does. Keep the supported
watches and the club-play note in step with `manifest.xml` and the README.

**What's New (1.0.0):** 1.0.0, first release: split timing with predicted stop
positions that learn the ice, fours and mixed doubles, shot tracking, sweep
counts and Garmin Connect activities.

## Other answers on the form

| Question | Answer |
|---|---|
| Category | Sports (no subcategory) |
| Collects user data | No |
| ANT+ profiles, regional limits, monetization | No |
| Icons for the app store on the device | No (optional) |
| Contact email (shown publicly) | doggos.watchface@proton.me |
| Source code URL | https://github.com/DannyPat44/curling-split-timer |
| Review notifications | Yes |
| Let the store add newly compatible watches | Yes |

## Publishing a new version

1. Merge the changes to `main` and check them: `make test`, the screens on
   every watch (`make screens`), and a real game if the change affects play.
2. Build the package: `make package` (writes `bin/Curling.iq`, signed with your
   developer key from `local.mk`).
3. On the dashboard, open Curling Split Timer and choose **Upload New Version**.
   Attach `bin/Curling.iq` and give the version (the last was 1.0.0), then
   **Upload and publish**.
4. On the next page (Update Details), write **What's New** for this version,
   and update the description, screenshots or video if the change calls for
   it (then update this file to match). **Submit**.
5. Garmin reviews it (up to 3 days); the listing shows "Version update
   pending" until then.
6. Tag the release in git: `git tag v1.0.1 && git push origin v1.0.1`.

A new demo video: `make video`, check `bin/video/curling-demo.mp4`, copy it
to `demo.mp4`, upload it to YouTube (not made for kids, public), and put the
link in the listing's Preview Video.

## Store quirks seen so far

- **"Signature check failed" on upload** with SDK 9.x, next to "Status:
  Verified": a known store bug. The submission still went through.
- **Broken image previews** on the dashboard and the edit form: they load from
  `api.appstore.garmin.com`, which often doesn't return them. The public
  listing shows the images fine.
- **"Trouble communicating with our servers"** on Submit: the change may have
  saved anyway; reload the edit page and check before submitting again.
- **On-device icons can't be replaced**: once 128x128 icons are submitted, new
  ones are refused ("There's an existing app icon..."), even after removing
  the old ones. Ask Garmin developer support.
- **Another browser extension can cover the edit form** after a file is
  attached, blocking clicks; reloading the page clears it.

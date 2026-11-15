# Curling app

A Connect IQ watch app for five-button Garmin watches (the list is in
manifest.xml). The README covers how it's played, the code layout and `make`
targets.

## After every change to the app

Unit tests aren't enough on their own: menus, the screen and the activity
file have each broken in ways only running the app showed. So for any change
to what the watch shows or records:

1. `make test`: all tests pass. New logic goes in the plain classes (`Game`,
   `Accuracy`, `SplitTable`, `Controls`, `KeyFilter`) with tests.
2. Check the screens in the simulator: `make sim-tools`, `make run`, then
   `. tools/screens.sh` and press through the changed flow (`press`, `hold`),
   capturing each screen with `shot` and looking at it (`tile` puts several
   side by side). Check every new or changed screen, menu and prompt, and the
   game screen before and after.
   For anything drawn on the game screen, also run `make screens` (the demo
   build on every watch, 218 to 454 px, MIP and AMOLED) and look at the
   captures; `swift tools/montage.swift out.png a.png b.png ...` lines them up.
   Look at a montage rather than each capture, or hand the batch to the
   `image-check` agent: every image read stays in context for the session.
3. If the change touches the activity (`GameFields`, `fitcontributions.xml`,
   saving): save a game in the simulator and run `make fit` to see the lap and
   summary fields that were actually written.
4. Show the user the captures that matter.

Driving the simulator:

- It clicks the simulator window's buttons, so it takes over the mouse.
  It needs Accessibility and Screen Recording for the terminal.
- Leave about 0.7 s between presses; a menu that's still opening misses
  them. Look at a capture after each step instead of pressing a long blind
  sequence.
- Holding Up (a hit) often arrives as a plain Up. Back > Skip rock moves the
  rotation on instead.
- The simulator keeps settings, the ice and an unsaved game between runs:
  check Settings (hold Up before a game) and answer the continue prompt.

## Activity fields

- A FitContributor `Field` must stay referenced until `session.save()`:
  one let go first is left out of the file (this dropped every summary field
  until Nov 2026). `recordingSavesEveryGameField` saves a real activity and
  `make test` checks its file (`tools/check_test_activity.py`); keep that
  check up to date when fields change. It fails if a game is still
  recording in the simulator (only one activity records at a time); the
  test run closes the app, so running it again passes.
- A sideloaded build writes a zero application id, so Garmin Connect may not
  label the app's fields; `make fit` reads them from the file either way.
- Strava ignores app fields and Connect IQ can't write an activity's notes.

## Rules of play

The app is for non-competitive club play. World Curling Rule R11(c) allows
only time data from a device during a game, so the predictions, ice speed and
stats would not be allowed in competition (see the README's "Is it legal in
a game?"). Keep that in mind when adding on-screen information.

## Saved data

Stop positions are stored by index in the ice marks and saved games. If the
positions change, convert old data on load (see `SplitTable.fromOldMarks`
and the `"positions"` count in a saved game) and test it.

## Install and publish

- `make install` copies the build onto the USB-connected watch.
- Publishing a new version and the listing's text and assets:
  `store/README.md`. Store descriptions lead with the value to a curler, then
  summarise what the app does.
- `make package` builds the `.iq` for the Connect IQ store, for every watch
  in the manifest. A new watch needs its device files from the SDK Manager,
  a line in the manifest, a launcher icon size in the jungles if it isn't
  60 px, and a look with `make screens`.
- Never commit Garmin's SDK or device files, or a developer key: the repo
  is public.

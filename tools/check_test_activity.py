"""Check the activity that test/RecordingTest.mc saved: every game field must
be in the file, with the values that test's game should give. Run by
`make test` on the newest activity the test run wrote.

    python check_test_activity.py game.fit
"""
import sys

import fitparse

# The last lap and the summary are written as the game is saved, and are
# the ones that lost their fields
LAST_LAP = {"End draw split": 3.9, "End points": 0}
FIRST_LAP = {"End draw split": 3.75, "End points": 1}
SUMMARY = {
    "Game": "Won 5-3 · Made 1/1 (100%)",
    "Points for": 5,
    "Points against": 3,
    "Second draw split": 3.8,
    "My shots made": 100,
    "Lead draw split": 0.0,
    "Skip draw split": 0.0,
}


def app_fields(message):
    # The app's fields are named in words ("Points for"), the FIT profile's
    # in snake_case
    return {d.name: d.value for d in message if d.name[:1].isupper()}


def check(name, fields, expected):
    problems = []
    for key, want in expected.items():
        if key not in fields:
            problems.append(f"{name}: {key} is missing")
        elif isinstance(want, float) and abs(fields[key] - want) > 0.001:
            problems.append(f"{name}: {key} is {fields[key]}, expected {want}")
        elif not isinstance(want, float) and fields[key] != want:
            problems.append(f"{name}: {key} is {fields[key]!r}, expected {want!r}")
    return problems


fit = fitparse.FitFile(sys.argv[1])
laps = [app_fields(m) for m in fit.get_messages("lap")]
sessions = [app_fields(m) for m in fit.get_messages("session")]
problems = []
# The simulator repeats the first lap after the last, so the last end's lap
# is the second, not the final one
if len(laps) < 2 or len(sessions) != 1:
    problems.append(f"expected 2 laps and a summary, found {len(laps)} laps and {len(sessions)} summaries")
else:
    problems += check("first lap", laps[0], FIRST_LAP)
    problems += check("last end's lap", laps[1], LAST_LAP)
    problems += check("summary", sessions[0], SUMMARY)
if problems:
    sys.exit(f"{sys.argv[1]}:\n  " + "\n  ".join(problems))
print(f"Activity check passed: {len(SUMMARY) + len(FIRST_LAP) + len(LAST_LAP)} game fields in {sys.argv[1]}")

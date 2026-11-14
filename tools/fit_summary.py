"""Print the app's fields from an activity file: each lap's and the summary.

    make fit                       (the simulator's newest activity)
    make fit FIT=path/to/game.fit  (one copied off the watch)

Needs fitparse; `make fit` installs it into bin/venv.
"""
import sys

import fitparse

fit = fitparse.FitFile(sys.argv[1])
try:
    for message in fit.get_messages(("lap", "session")):
        # The app's own fields are the ones named in words ("Points for"),
        # the FIT profile's are snake_case
        fields = {d.name: d.value for d in message if d.name[:1].isupper()}
        print(f"{message.name:8} {fields}")
except fitparse.FitCRCError:
    sys.exit(f"{sys.argv[1]} is unfinished: save the game first")

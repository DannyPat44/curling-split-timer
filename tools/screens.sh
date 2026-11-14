# Helpers for checking screens in the simulator, sourced into a shell:
#     make sim-tools && make run
#     . tools/screens.sh
#     press start; sleep 3.7; press start   # time a rock
#     press up down start                   # place it deeper, log it
#     shot logged                           # bin/screens/logged.png
#     tile run logged menu                  # bin/screens/run.png, faces side by side
# Then look at the PNGs. Holding Up for a hit is unreliable through the
# simulator; Back > Skip rock moves the rotation on instead.
SCREENS=bin/screens
mkdir -p "$SCREENS"

# Press buttons one after another (start, back, up, down, light)
press() { for b in "$@"; do bin/sim press "$b"; sleep 0.7; done; }
# Hold a button (Up: the menu key, a hit during a game)
hold() { bin/sim hold "$1"; sleep 0.8; }
# Capture the simulator window as bin/screens/<name>.png
shot() { sleep 0.4; bin/sim shot "$SCREENS/$1.png"; }
# Put captures side by side, cropped to the face: tile <out> <name>...
tile() { local out=$1; shift; local f; local files=(); for f in "$@"; do files+=("$SCREENS/$f.png"); done; swift tools/tile.swift "$SCREENS/$out.png" "${files[@]}"; }

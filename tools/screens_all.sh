#!/bin/bash
# The demo build on every watch in the manifest (or those given), in the
# simulator: captures bin/screens/<watch>-sheet.png (a split being placed)
# and <watch>-team.png (the team list). Needs bin/sim (make sim-tools).
#     tools/screens_all.sh [watch...]
set -e
cd "$(dirname "$0")/.."
SDK=$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")
KEY=$(make -s -f - print-key <<'MK'
-include local.mk
KEY ?= developer_key.der
print-key: ; @echo $(KEY)
MK
)
devices=("$@")
if [ ${#devices[@]} -eq 0 ]; then
    devices=($(sed -n 's/.*<iq:product id="\([^"]*\)".*/\1/p' manifest.xml))
fi
mkdir -p bin/screens
pgrep -qf ConnectIQ.app || { "${SDK}bin/connectiq"; sleep 5; }
for d in "${devices[@]}"; do
    "${SDK}bin/monkeyc" -f demo.jungle -d "$d" -y "$KEY" -o "bin/Demo-$d.prg" -w > /dev/null
    "${SDK}bin/monkeydo" "bin/Demo-$d.prg" "$d" > /dev/null 2>&1 &
    # The simulator switches watch and the demo sets its game up; the team
    # list follows 10 s after it starts
    sleep 6
    bin/sim shot "bin/screens/$d-sheet.png"
    sleep 8
    bin/sim shot "bin/screens/$d-team.png"
    echo "$d"
done

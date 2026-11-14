#!/bin/bash
# Record the store's demo video: the video build (video.jungle) plays a
# scripted game on the Forerunner 265 in the simulator while ffmpeg records
# the screen; then tools/make_video.sh crops it to the watch and adds the
# captions. Output: bin/video/curling-demo.mp4 (copy it to store/demo.mp4).
#     make video
# Needs ffmpeg (brew install ffmpeg), Pillow, bin/sim (make sim-tools), and
# Screen Recording for the terminal. Keep the simulator window uncovered.
set -e
cd "$(dirname "$0")/.."
SDK=$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")
KEY=$(make -s -f - print-key <<'MK'
-include local.mk
KEY ?= developer_key.der
print-key: ; @echo $(KEY)
MK
)
mkdir -p bin/video
"${SDK}bin/monkeyc" -f video.jungle -d fr265 -y "$KEY" -o bin/Video-fr265.prg -w > /dev/null
pgrep -qf ConnectIQ.app || { "${SDK}bin/connectiq"; sleep 6; }

# A first run puts the simulator on the FR265 and clears any earlier
# activity (only one records at a time); the second is the one recorded
"${SDK}bin/monkeydo" bin/Video-fr265.prg fr265 > /dev/null 2>&1 &
sleep 40

# The window in screen pixels (a Retina screen has 2 pixels a point)
IFS=, read -r x y w h <<< "$(bin/sim bounds)"
scale=2
screen=$(ffmpeg -hide_banner -f avfoundation -list_devices true -i "" 2>&1 \
    | sed -n 's/.*\[\([0-9]*\)\] Capture screen 0.*/\1/p' | head -1)
ffmpeg -v error -y -f avfoundation -capture_cursor 0 -framerate 30 -i "$screen:none" -t 44 \
    -vf "crop=$((w * scale)):$((h * scale)):$((x * scale)):$((y * scale))" \
    -c:v libx264 -preset ultrafast -crf 16 bin/video/raw.mp4 &
recorder=$!
sleep 2
"${SDK}bin/monkeydo" bin/Video-fr265.prg fr265 > /dev/null 2>&1 &
wait $recorder

# When the first timing begins: the split goes from a dim 0.00 to white
start=$(python3 - <<'PY'
import subprocess
# One small frame of the split's area every 0.05 s
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", "bin/video/raw.mp4", "-vf",
    "fps=20,crop=300:150:497:700,format=gray", "-f", "rawvideo", "-"], capture_output=True).stdout
size = 300 * 150
seen_dim = False
for i in range(len(raw) // size):
    peak = max(raw[i * size:(i + 1) * size])
    if peak < 200:
        seen_dim = True
    elif seen_dim and peak > 245:
        print(f"{i / 20:.2f}")
        break
PY
)
echo "First timing at ${start}s"
tools/make_video.sh bin/video/raw.mp4 "$start"

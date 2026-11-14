#!/bin/bash
# The store's demo video from a recording of the video build (make video):
# the watch screen on a square black frame, with a caption for each step.
#     tools/make_video.sh bin/video/raw.mov START
# START is when, in the recording, the first timing began (the split leaves
# 0.00); the captions in tools/video_captions.txt are timed from it.
# Needs ffmpeg, and Pillow for the captions.
set -e
raw=$1
start=$2
out=bin/video
mkdir -p "$out"
python3 - "$out" "$start" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
out, start = sys.argv[1], float(sys.argv[2])
font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 44)
mask = Image.new("RGBA", (832, 832), (0, 0, 0, 255))
ImageDraw.Draw(mask).ellipse((4, 4, 828, 828), fill=(0, 0, 0, 0))
mask.save(f"{out}/mask.png")
with open(f"{out}/captions.tsv", "w") as times:
    for i, line in enumerate(open("tools/video_captions.txt"), 1):
        a, b, text = line.rstrip("\n").split(" ", 2)
        img = Image.new("RGBA", (1080, 110), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.text(((1080 - d.textlength(text, font=font)) / 2, 30), text, font=font, fill="white")
        img.save(f"{out}/cap{i}.png")
        # In the clip, which starts a second before the first timing
        times.write(f"{max(float(a) + 1, 0):.2f} {float(b) + 1:.2f}\n")
PY
# One second before the first timing, to a second after the last caption
begin=$(echo "$start - 1" | bc)
length=$(awk 'END {print $2 + 0.5}' "$out/captions.tsv")
inputs=(-ss "$begin" -t "$length" -i "$raw" -i "$out/mask.png")
chain="[0]fps=30,crop=832:832:231:509[w];[w][1]overlay=0:0[f];[f]pad=1080:1080:124:40:black[v0]"
i=0
while read -r a b; do
    i=$((i + 1))
    inputs+=(-i "$out/cap$i.png")
    chain="$chain;[v$((i - 1))][$((i + 1))]overlay=0:930:enable='between(t,$a,$b)'[v$i]"
done < "$out/captions.tsv"
ffmpeg -v error -y "${inputs[@]}" -filter_complex "$chain;[v$i]format=yuv420p[out]" -map "[out]" \
    -c:v libx264 -crf 20 -preset slow -movflags +faststart "$out/curling-demo.mp4"
echo "$out/curling-demo.mp4"

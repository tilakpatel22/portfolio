#!/usr/bin/env bash
# Generates Play Store / social media from real gameplay (high-rush showcase):
#   store/video/gameplay_30s.mp4      30 s 1080p H.264 + AAC
#   store/screenshots/*.jpg           captioned 1920x1080 screenshots
# Requirements: Godot 4.7.2 on PATH (or GODOT=...), ffmpeg, python3 + pillow.
# Headless Linux: runs under xvfb-run automatically when no display is available.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=build/media
mkdir -p "$OUT" store/video store/screenshots
RUN=()
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then
	RUN=(xvfb-run -a -s "-screen 0 1920x1080x24")
fi
GD=("${RUN[@]}" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30)

echo "1/4 Recording 30 s showcase video (level 45, rush hour)..."
"${GD[@]}" --write-movie "$OUT/raw.avi" res://tools/showcase.tscn -- \
	--level=45 --length=30 --menu=2.5 --calm_at=14 --win_at=26.5 --shots=7,11,15.5,19,23,29 --prefix=v

echo "2/4 Extra stills from other maps..."
for L in 35 25 12; do
	"${GD[@]}" res://tools/showcase.tscn -- --level=$L --length=11 --menu=0.3 --calm_at=99 --win_at=99 --shots=10 --prefix=l$L
done

echo "3/4 Encoding MP4..."
ffmpeg -y -loglevel error -i "$OUT/raw.avi" -t 30 -c:v libx264 -preset slow -crf 19 -pix_fmt yuv420p \
	-c:a aac -b:a 160k -movflags +faststart store/video/gameplay_30s.mp4

echo "4/4 Captioned screenshots..."
python3 tools/make_screenshots.py

echo "Done: store/video/gameplay_30s.mp4 and store/screenshots/"

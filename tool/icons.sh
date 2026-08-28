#!/usr/bin/env bash
# Redraws every icon the app ships, from the SVGs beside them.
#
# sips is macOS's own and rasterises SVG, so there is nothing to install. Each
# source sits next to its output on purpose: an icon whose source lives
# somewhere else is an icon nobody ever edits again.
#
# Four drawings, because one cannot do all four jobs:
#   web/icon.svg           rounded, for the PWA
#   web/icon-small.svg     fatter strokes, for 16 and 32 px where detail dies
#   web/icon-maskable.svg  full bleed, mark inside the middle 80 %
#   macos/…/icon-macos.svg 824 in a 1024 canvas, which is how macOS draws them
#   ios/…/icon-ios.svg     full bleed and square; iOS masks it itself
set -euo pipefail
cd "$(dirname "$0")/../app"

for size in 192 512; do
  sips -s format png -Z $size web/icon.svg --out "web/icons/Icon-$size.png" >/dev/null
  sips -s format png -Z $size web/icon-maskable.svg \
    --out "web/icons/Icon-maskable-$size.png" >/dev/null
done
sips -s format png -Z 32 web/icon-small.svg --out web/favicon.png >/dev/null

mac=macos/Runner/Assets.xcassets/AppIcon.appiconset
for size in 16 32 64 128 256 512 1024; do
  sips -s format png -Z $size "$mac/icon-macos.svg" \
    --out "$mac/app_icon_$size.png" >/dev/null
done

# The iOS set is a list rather than a pattern, so it comes from its own manifest.
python3 - <<'PY'
import json, subprocess
root = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
images = json.load(open(f'{root}/Contents.json'))['images']
done = set()
for image in images:
    name = image.get('filename')
    if not name or name in done:
        continue
    done.add(name)
    side = float(image['size'].split('x')[0]) * int(image['scale'].rstrip('x'))
    subprocess.run(
        ['sips', '-s', 'format', 'png', '-Z', str(int(side)),
         f'{root}/icon-ios.svg', '--out', f'{root}/{name}'],
        capture_output=True, check=True)
print(f'{len(done)} iOS icons')
PY

echo "redrew the web, macOS and iOS icons"

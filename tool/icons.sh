#!/usr/bin/env bash
# Redraws every icon the web build ships, from the three SVGs beside them.
#
# sips is macOS's own and rasterises SVG, so there is nothing to install. The
# sources live in app/web next to their output on purpose: an icon whose
# source is somewhere else is an icon nobody ever edits again.
set -euo pipefail
cd "$(dirname "$0")/../app/web"

for size in 192 512; do
  sips -s format png -Z $size icon.svg --out "icons/Icon-$size.png" >/dev/null
  sips -s format png -Z $size icon-maskable.svg \
    --out "icons/Icon-maskable-$size.png" >/dev/null
done
sips -s format png -Z 32 icon-small.svg --out favicon.png >/dev/null

echo "redrew 4 icons and the favicon"

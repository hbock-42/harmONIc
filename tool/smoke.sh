#!/usr/bin/env bash
# Build the app as an app, start it, and make sure it stays up.
#
# `flutter test` never does this. A widget test runs the widgets in a harness
# that has no bundle, no plugins and no file system — which is why the guide
# panel takes an injectable loader and the exporter an injectable directory.
# Everything those seams hide from the tests is exactly what this checks:
# that the guide is really in the bundle, that path_provider is really
# registered, and that the thing opens.
#
# Not in CI: the runners have no desktop, and a Linux build would be checking
# a platform nobody here runs. Run it before calling anything shippable.
set -euo pipefail
cd "$(dirname "$0")/.."

app="app/build/macos/Build/Products/Debug/harmONIc.app"
assets="$app/Contents/Frameworks/App.framework/Resources/flutter_assets/assets"

echo "== build =="
(cd app && fvm flutter build macos --debug)

echo "== the guide really shipped =="
diff "$assets/using.md" docs/USING.md >/dev/null
echo "assets/using.md in the bundle matches docs/USING.md"

echo "== it opens =="
# A crash on startup — a missing asset, an unregistered plugin — shows up as a
# process that is not there a few seconds later.
open "$app"
sleep 6
if pgrep -x harmONIc >/dev/null; then
  echo "it is running"
  pkill -x harmONIc
  echo "and closed again"
else
  echo "it did not stay up" >&2
  exit 1
fi

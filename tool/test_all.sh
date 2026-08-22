#!/usr/bin/env bash
# Analyze + test everything, with the FVM-pinned SDK.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== engine =="
(cd packages/oni_engine && fvm dart pub get && fvm dart analyze && fvm dart test)

echo "== app =="
(cd app && fvm flutter pub get && fvm flutter analyze && fvm flutter test)

echo "== shipped docs =="
(./tool/copy_docs.sh >/dev/null &&
  git diff --exit-code app/assets/using.md >/dev/null &&
  echo "app/assets/using.md matches docs/USING.md")

# The same check CI makes: the committed generated data has to match the JSON
# it was generated from, or the app and the source of truth have drifted.
echo "== generated data =="
(cd packages/oni_engine && fvm dart run tool/gen_data.dart >/dev/null &&
  git diff --exit-code lib/src/data/oni_data.g.dart >/dev/null &&
  echo "oni_data.g.dart is up to date")

#!/usr/bin/env bash
# Analyze + test everything, with the FVM-pinned SDK.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== engine =="
(cd packages/oni_engine && fvm dart pub get && fvm dart analyze && fvm dart test)

echo "== app =="
(cd app && fvm flutter pub get && fvm flutter analyze && fvm flutter test)

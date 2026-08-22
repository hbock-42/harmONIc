#!/usr/bin/env bash
# Copies the docs the app ships into its assets.
#
# docs/USING.md is the canonical copy — it is what somebody reads in the
# repository — and the app cannot load a file outside its own package, so it
# gets one. Two copies of anything drift, so this makes the second and
# tool/test_all.sh checks it has not.
set -euo pipefail
cd "$(dirname "$0")/.."
cp docs/USING.md app/assets/using.md
echo "copied docs/USING.md -> app/assets/using.md"

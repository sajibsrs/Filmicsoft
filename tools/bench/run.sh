#!/bin/sh
# GPU cost of each Filmicsoft pass, measured offscreen (macOS).
# Usage: tools/bench/run.sh [WIDTH HEIGHT]   (default: 1920x1080 and 2880x1800)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
PACK="${PACK:-$HERE/../../pack/shaders}"
BUILD="${TMPDIR:-/tmp}/filmicsoft-bench"
mkdir -p "$BUILD"
clang -O2 -o "$BUILD/bench" "$HERE/bench.c" -framework OpenGL -lm
rm -rf "$BUILD/out"
python3 -I "$HERE/../glcheck/prep.py" "$PACK" "$BUILD/out"
if [ $# -ge 2 ]; then
  "$BUILD/bench" "$1" "$2" "$BUILD/out" "$PACK/shaders.properties"
else
  "$BUILD/bench" 1920 1080 "$BUILD/out" "$PACK/shaders.properties"
  echo
  "$BUILD/bench" 2880 1800 "$BUILD/out" "$PACK/shaders.properties"
fi

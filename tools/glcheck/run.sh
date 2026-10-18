#!/bin/sh
# Compile every .fsh in the pack with the platform's real GLSL compiler (macOS).
# Catches Apple-strictness errors before launching the game.
# Note: it cannot catch Iris-specific rules (e.g. buffer-format constants must
# sit inside a comment) - launch the game and read logs/latest.log for those.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
PACK="${1:-$HERE/../../pack/shaders}"
BUILD="${TMPDIR:-/tmp}/filmicsoft-glcheck"
mkdir -p "$BUILD"
clang -o "$BUILD/check" "$HERE/check.c" -framework OpenGL
rm -rf "$BUILD/out"
python3 -I "$HERE/prep.py" "$PACK" "$BUILD/out"
"$BUILD/check" $(for f in "$BUILD"/out/*.fsh; do echo fs "$f"; done) $(for f in "$BUILD"/out/*.vsh; do echo vs "$f"; done)

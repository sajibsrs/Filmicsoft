#!/bin/sh
# Copy the pack into a Minecraft game directory's shaderpacks folder.
# Usage: scripts/install.sh [game-dir]
#   game-dir defaults to $MINECRAFT_DIR, else the macOS default (~/Library/Application Support/minecraft).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="${1:-${MINECRAFT_DIR:-$HOME/Library/Application Support/minecraft}}"
DEST="$GAME/shaderpacks/Filmicsoft"
[ -d "$GAME" ] || { echo "No such game directory: $GAME" >&2; exit 1; }
rsync -a --delete "$HERE/../pack/" "$DEST/"
echo "Installed to: $DEST"

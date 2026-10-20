#!/bin/sh
# Copy the pack into a Minecraft game directory's shaderpacks folder.
# Usage: scripts/install.sh [game-dir]
#   game-dir defaults to $MINECRAFT_DIR, else the Prism Launcher instance "26.3"
#   (override the name with PRISM_INSTANCE), else the macOS vanilla default.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
PRISM="$HOME/Library/Application Support/PrismLauncher/instances/${PRISM_INSTANCE:-26.3}/minecraft"
VANILLA="$HOME/Library/Application Support/minecraft"
if [ -n "$1" ]; then GAME="$1"
elif [ -n "$MINECRAFT_DIR" ]; then GAME="$MINECRAFT_DIR"
elif [ -d "$PRISM" ]; then GAME="$PRISM"
else GAME="$VANILLA"
fi
DEST="$GAME/shaderpacks/Filmicsoft"
[ -d "$GAME" ] || { echo "No such game directory: $GAME" >&2; exit 1; }
rsync -a --delete "$HERE/../pack/" "$DEST/"
echo "Installed to: $DEST"

#!/bin/sh
# Copy the pack into a Prism Launcher instance's shaderpacks folder.
# Usage: scripts/install.sh ["Instance Name"]
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
INSTANCE="${1:-Fabulously Optimized}"
PRISM="${PRISM_DIR:-$HOME/Library/Application Support/PrismLauncher}"
# Prism names the folder after the instance id, which is the directory name.
DEST="$PRISM/instances/$INSTANCE/minecraft/shaderpacks/Filmicsoft"
[ -d "$PRISM/instances/$INSTANCE" ] || { echo "No such instance: $INSTANCE" >&2; exit 1; }
rsync -a --delete "$HERE/../pack/" "$DEST/"
echo "Installed to: $DEST"

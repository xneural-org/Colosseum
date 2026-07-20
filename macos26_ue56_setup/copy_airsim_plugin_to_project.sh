#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
UE_PATH="${UE_PATH:-/Users/Shared/Epic Games/UE_5.6}"
BUILD_AFTER_COPY="${BUILD_AFTER_COPY:-0}"
TARGET_NAME="${TARGET_NAME:-}"

usage() {
    echo "usage: $0 /path/to/MyProject.uproject" >&2
    echo "optional: UE_PATH=/path/to/UE_5.6 BUILD_AFTER_COPY=1 TARGET_NAME=MyProjectEditor $0 /path/to/MyProject.uproject" >&2
}

[[ $# -eq 1 ]] || { usage; exit 2; }

PROJECT_FILE_INPUT="$1"
PROJECT_DIR="$(cd "$(dirname "$PROJECT_FILE_INPUT")" && pwd)"
PROJECT_FILE="$PROJECT_DIR/$(basename "$PROJECT_FILE_INPUT")"
PROJECT_NAME="$(basename "$PROJECT_FILE" .uproject)"
AIRSIM_SRC="$ROOT_DIR/Unreal/Plugins/AirSim"
AIRSIM_DEST="$PROJECT_DIR/Plugins/AirSim"

[[ -f "$PROJECT_FILE" ]] || { echo "error: project file not found: $PROJECT_FILE" >&2; exit 1; }
[[ -d "$AIRSIM_SRC" ]] || { echo "error: AirSim plugin source not found: $AIRSIM_SRC" >&2; exit 1; }
[[ -f "$ROOT_DIR/AirLib/lib/arm64/Release/libAirLib.a" ]] || {
    echo "error: AirLib is not built. Run macos26_ue56_setup/setup_colosseum_macos26_ue56.sh first." >&2
    exit 1
}

echo "==> Copying AirSim plugin"
mkdir -p "$PROJECT_DIR/Plugins"
rsync -a --delete \
    --exclude 'Binaries' \
    --exclude 'Intermediate' \
    --exclude 'Saved' \
    "$AIRSIM_SRC/" "$AIRSIM_DEST/"

echo "==> Syncing built AirLib dependencies"
rsync -a --delete "$ROOT_DIR/AirLib" "$AIRSIM_DEST/Source/"

echo "==> Enabling AirSim in $(basename "$PROJECT_FILE")"
python3 - "$PROJECT_FILE" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
plugins = data.setdefault("Plugins", [])

for plugin in plugins:
    if plugin.get("Name") == "AirSim":
        plugin["Enabled"] = True
        break
else:
    plugins.append({"Name": "AirSim", "Enabled": True})

path.write_text(json.dumps(data, indent="\t") + "\n")
PY

echo "==> Generating project files"
"$UE_PATH/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh" "$PROJECT_FILE"

if [[ "$BUILD_AFTER_COPY" == "1" ]]; then
    if [[ -z "$TARGET_NAME" ]]; then
        TARGET_NAME="${PROJECT_NAME}Editor"
    fi
    echo "==> Building $TARGET_NAME"
    "$UE_PATH/Engine/Build/BatchFiles/Mac/Build.sh" "$TARGET_NAME" Mac Development -Project="$PROJECT_FILE" -WaitMutex
else
    echo
    echo "AirSim copied. Open the project with:"
    echo "open \"$PROJECT_FILE\""
    echo
    echo "To build now:"
    echo "BUILD_AFTER_COPY=1 TARGET_NAME=${PROJECT_NAME}Editor $0 \"$PROJECT_FILE\""
fi

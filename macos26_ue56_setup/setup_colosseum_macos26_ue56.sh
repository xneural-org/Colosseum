#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
UE_PATH="${UE_PATH:-/Users/Shared/Epic Games/UE_5.6}"
PROJECT_DIR="${PROJECT_DIR:-$ROOT_DIR/Unreal/Environments/BlocksV2}"
VENV_DIR="${VENV_DIR:-$ROOT_DIR/.tools/colosseum-venv}"

die() {
    echo "error: $*" >&2
    exit 1
}

require_file() {
    [[ -e "$1" ]] || die "missing required path: $1"
}

version_le() {
    python3 - "$1" "$2" <<'PY'
import re
import sys

def parts(value):
    return [int(item) for item in re.findall(r"\d+", value)]

left = parts(sys.argv[1])
right = parts(sys.argv[2])
size = max(len(left), len(right))
left += [0] * (size - len(left))
right += [0] * (size - len(right))
sys.exit(0 if left <= right else 1)
PY
}

echo "==> Checking Unreal Engine"
require_file "$UE_PATH/Engine/Build/BatchFiles/Mac/Build.sh"
require_file "$UE_PATH/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh"

echo "==> Checking Xcode"
DEVELOPER_DIR_SELECTED="$(xcode-select -p 2>/dev/null || true)"
[[ -n "$DEVELOPER_DIR_SELECTED" ]] || die "xcode-select is not configured"
[[ "$DEVELOPER_DIR_SELECTED" != *CommandLineTools* ]] || die "Unreal needs full Xcode. Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
xcodebuild -version >/dev/null || die "xcodebuild failed. Open Xcode once, accept the license, or run sudo xcodebuild -license accept"

if ! xcrun metal -v >/dev/null 2>&1; then
    echo "==> Installing Xcode Metal Toolchain"
    xcodebuild -downloadComponent MetalToolchain
fi

if [[ "$(uname -m)" == "arm64" ]] && ! arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    echo "==> Installing Rosetta"
    sudo softwareupdate --install-rosetta --agree-to-license
fi

echo "==> Patching UE Apple SDK version gate"
SDK_JSON="$UE_PATH/Engine/Config/Apple/Apple_SDK.json"
require_file "$SDK_JSON"
python3 - "$SDK_JSON" <<'PY'
import datetime
import json
import pathlib
import shutil
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
changed = False

if data.get("MaxVersion") != "26.9.0":
    data["MaxVersion"] = "26.9.0"
    changed = True

mapping = data.setdefault("AppleVersionToLLVMVersions", [])
if "21.0.0-21.0.0" not in mapping:
    mapping.append("21.0.0-21.0.0")
    changed = True

if changed:
    stamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    backup = path.with_name(path.name + f".bak-macos26-ue56-{stamp}")
    shutil.copy2(path, backup)
    path.write_text(json.dumps(data, indent="\t") + "\n")
    print(f"patched {path}")
    print(f"backup  {backup}")
else:
    print(f"already patched {path}")
PY

echo "==> Installing local CMake"
python3 -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --upgrade pip cmake
export PATH="$VENV_DIR/bin:$PATH"

echo "==> Running Colosseum setup"
cd "$ROOT_DIR"
bash ./setup.sh

echo "==> Building Colosseum static libraries"
if [[ "${CLEAN_BUILD:-1}" == "1" ]]; then
    rm -rf "$ROOT_DIR/build"
else
    echo "    Reusing the existing build directory (CLEAN_BUILD=0)"
fi
CMAKE="$VENV_DIR/bin/cmake" bash ./build.sh

echo "==> Syncing AirSim plugin into BlocksV2"
require_file "$PROJECT_DIR/BlocksV2.uproject"
bash "$PROJECT_DIR/clean.sh"
mkdir -p "$PROJECT_DIR/Plugins"
rsync -a --exclude 'temp' --delete "$ROOT_DIR/Unreal/Plugins/AirSim" "$PROJECT_DIR/Plugins/"
rsync -a --exclude 'temp' --delete "$ROOT_DIR/AirLib" "$PROJECT_DIR/Plugins/AirSim/Source/"

echo "==> Generating BlocksV2 project files"
bash "$PROJECT_DIR/GenerateProjectFiles.sh" "$UE_PATH"

echo "==> Building BlocksV2Editor"
"$UE_PATH/Engine/Build/BatchFiles/Mac/Build.sh" BlocksV2Editor Mac Development -Project="$PROJECT_DIR/BlocksV2.uproject" -WaitMutex

echo
echo "Done. Open the project with:"
echo "open \"$PROJECT_DIR/BlocksV2.uproject\""

# Build Colosseum on macOS 26 and Unreal Engine 5.6

This source tree contains the compatibility changes needed to build the
Colosseum AirSim plugin on an Apple Silicon Mac with macOS 26.x, Xcode 26.x,
and Unreal Engine 5.6.x.

## Prerequisites

### Step 1: Install Unreal Engine 5.6

1. Download and install the Epic Games Launcher.
2. Open the launcher and sign in.
3. Open **Unreal Engine > Library**.
4. Install Unreal Engine 5.6.x. This build was tested with UE 5.6.1.

The setup script expects Unreal Engine at: /Users/Shared/Epic Games/UE_5.6
When use another location, you must provide it through `UE_PATH` when running the setup script.

### Step 2: Install and initialize Xcode

1. Install the full Xcode application from the Apple App Store.
2. Open Xcode once and allow it to install any requested components.
3. Run these commands in Terminal:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
```
This only needs to be run once after installing or replacing Xcode.

Verify the Xcode, Metal, and Rosetta setup with:

```bash
xcode-select -p
xcodebuild -version
xcrun metal -v
arch -x86_64 /usr/bin/true && echo rosetta-ok
```

Example output from a correctly configured Mac:

```text
/Applications/Xcode.app/Contents/Developer
Xcode 26.6
Build version 17F113
Apple metal version 32023.883 (metalfe-32023.883)
Target: air64-apple-darwin25.5.0
Thread model: posix
InstalledDir: /.../Metal.xctoolchain/usr/metal/current/bin
rosetta-ok
```

The exact Xcode, build, Metal, target, and installation-path values may differ
between machines. The expected results are the full Xcode developer path, a
Metal compiler version without an error, and `rosetta-ok` on the final line.

### Step 3: Prepare the Colosseum source

Extract this source archive or clone the patched repository. Then open Terminal
and enter the source directory:

```bash
cd /path/to/Colosseum-macos26-ue56-arm64
```

## Build From the Beginning

From the Colosseum source directory, run:

```bash
bash macos26_ue56_setup/setup_colosseum_macos26_ue56.sh
```

The normal command performs a clean build. It:

1. Checks Unreal Engine and Xcode.
2. Installs the Metal Toolchain or Rosetta if either is missing.
3. Backs up and patches UE 5.6's Apple SDK version configuration.
4. Creates a local Python virtual environment and installs CMake inside it.
5. Builds AirLib and its dependencies for Apple Silicon.
6. Copies the AirSim plugin into the BlocksV2 project.
7. Generates the Unreal project files.
8. Builds `BlocksV2Editor` for Mac Development.


## Use a Non-default Unreal Engine Location

If Unreal Engine is installed somewhere else, run:

```bash
UE_PATH="/path/to/UE_5.6" \
bash macos26_ue56_setup/setup_colosseum_macos26_ue56.sh
```

The default Unreal project is:

```text
Unreal/Environments/BlocksV2/BlocksV2.uproject
```

## Open the Project

After the script reports success, open BlocksV2 with:

```bash
open Unreal/Environments/BlocksV2/BlocksV2.uproject
```

If Epic Games Launcher repairs or updates UE 5.6, rerun the setup script. The
launcher may restore the Apple SDK configuration that the script patches.

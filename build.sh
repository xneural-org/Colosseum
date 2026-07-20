#! /bin/bash
set -e

RPC_VERSION_FOLDER="rpclib-2.3.0"
folder_name="Release"
build_dir=build
CMAKE_BIN="${CMAKE:-cmake}"

if [[ "$(uname)" == "Darwin" ]]; then
    JOBS="$(sysctl -n hw.ncpu)"
else
    JOBS="$(nproc)"
fi

mkdir -p build
cd build

if [[ "$(uname)" == "Darwin" ]]; then
    echo "Building for macOS"
    CC="${CC:-$(xcrun --find clang)}" \
    CXX="${CXX:-$(xcrun --find clang++)}" \
    "$CMAKE_BIN" ../cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
        -DCMAKE_APPLE_SILICON_PROCESSOR=arm64
else
    echo "Building for Linux"
    CC="${CC:-/usr/bin/clang-18}" CXX="${CXX:-/usr/bin/clang++-18}" \
    "$CMAKE_BIN" ../cmake \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_CXX_FLAGS='-stdlib=libc++ -I/usr/lib/llvm-17/include/c++/v1~'
fi

make -j"$JOBS"

cd ..

mkdir -p AirLib/lib
mkdir -p AirLib/deps/rpclib/lib
mkdir -p AirLib/deps/MavLinkCom/lib
cp "$build_dir/output/lib/libAirLib.a" AirLib/lib/libAirLib.a
cp "$build_dir/output/lib/libMavLinkCom.a" AirLib/deps/MavLinkCom/lib/libMavLinkCom.a
cp "$build_dir/output/lib/librpc.a" AirLib/deps/rpclib/lib/librpc.a

# Update AirLib/lib, AirLib/deps, Plugins folders with new binaries
if [[ "$(uname)" == "Darwin" ]]; then
    mkdir -p AirLib/lib/arm64/$folder_name
    rsync -a --delete build/output/lib/ AirLib/lib/arm64/$folder_name
else
    mkdir -p AirLib/lib/x64/$folder_name
    rsync -a --delete build/output/lib/ AirLib/lib/x64/$folder_name
fi
rsync -a --delete external/rpclib/$RPC_VERSION_FOLDER/include AirLib/deps/rpclib
rsync -a --delete MavLinkCom/include AirLib/deps/MavLinkCom
rsync -a --delete AirLib Unreal/Plugins/AirSim/Source
rm -rf Unreal/Plugins/AirSim/Source/AirLib/src

# The setup wrapper handles its configured project explicitly. Keep the legacy
# bulk sync available for developers who intentionally opt into it.
if [[ "${SYNC_UNREAL_PROJECTS:-0}" == "1" ]]; then
    for d in ~/Documents/Unreal\ Projects/*; do
        [ -d "$d" ] || continue
        [ -L "${d%/}" ] && continue

        if [ -x "$d/clean.sh" ]; then
            "$d/clean.sh"
        fi

        mkdir -p "$d/Plugins"
        rsync -a --delete Unreal/Plugins/AirSim/ "$d/Plugins/AirSim/"
    done
fi

echo ""
echo ""
echo "=================================================================="
echo " Colosseum plugin is built! Here's how to build Unreal project."
echo "=================================================================="
echo "All environments under Unreal/Environments have been updated."
echo ""
echo "For further info see the docs:"
echo "https://codexlabsllc.github.io/Colosseum/build_linux/"
echo "=================================================================="

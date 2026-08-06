#! /bin/bash
set -e

# CMake >= 4.0 refuses sub-projects declaring cmake_minimum_required < 3.5
export CMAKE_POLICY_VERSION_MINIMUM=3.5

RPC_VERSION_FOLDER="rpclib-2.3.0"
folder_name="Release"
build_dir=build

mkdir -p build
cd build

CC=/usr/bin/clang-18 CXX=/usr/bin/clang++-18 cmake ../cmake -DCMAKE_CXX_FLAGS='-stdlib=libc++'

make -j$(nproc)

cd ..

# --- UE-compatible rpclib ---------------------------------------------------
# UE links plugins against its bundled glibc-2.28 sysroot. On hosts with
# glibc >= 2.30, libc++ makes librpc.a reference pthread_cond_clockwait,
# which that sysroot lacks -> undefined symbol when linking the plugin.
# Detect the reference and, if present, rebuild rpclib with UE's toolchain.
if nm -u "$build_dir/output/lib/librpc.a" | grep -q pthread_cond_clockwait; then
    UE_ROOT="${UE_ROOT:-$HOME/apps/UnrealEngine-5.6.1}"
    UE_TC="$UE_ROOT/Engine/Extras/ThirdPartyNotUE/SDKs/HostLinux/Linux_x64/v25_clang-18.1.0-rockylinux8/x86_64-unknown-linux-gnu"
    UE_LIBCXX="$UE_ROOT/Engine/Source/ThirdParty/Unix/LibCxx"
    if [ -x "$UE_TC/bin/clang++" ]; then
        echo "librpc.a references pthread_cond_clockwait -> rebuilding rpclib with the UE toolchain"
        mkdir -p "external/rpclib/$RPC_VERSION_FOLDER/build_ue"
        pushd "external/rpclib/$RPC_VERSION_FOLDER/build_ue" >/dev/null
        CC="$UE_TC/bin/clang" CXX="$UE_TC/bin/clang++" cmake .. \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_CXX_FLAGS="--sysroot=$UE_TC -nostdinc++ -I$UE_LIBCXX/include -I$UE_LIBCXX/include/c++/v1"
        make -j$(nproc)
        popd >/dev/null
        RPCA=$(find "external/rpclib/$RPC_VERSION_FOLDER/build_ue" -name librpc.a | head -1)
        cp "$RPCA" "$build_dir/output/lib/librpc.a"
        echo "UE-compatible librpc.a swapped in"
    else
        echo "ERROR: librpc.a needs a UE-toolchain rebuild, but no toolchain found at:"
        echo "       $UE_TC"
        echo "       Set UE_ROOT to your Unreal Engine 5.6 install and re-run ./build.sh"
        exit 1
    fi
fi
# -----------------------------------------------------------------------------

mkdir -p AirLib/lib/x64/$folder_name
mkdir -p AirLib/deps/rpclib/lib
mkdir -p AirLib/deps/MavLinkCom/lib
cp $build_dir/output/lib/libAirLib.a AirLib/lib
cp $build_dir/output/lib/libMavLinkCom.a AirLib/deps/MavLinkCom/lib
cp $build_dir/output/lib/librpc.a AirLib/deps/rpclib/lib/librpc.a

# Update AirLib/lib, AirLib/deps, Plugins folders with new binaries
rsync -a --delete build/output/lib/ AirLib/lib/x64/$folder_name
rsync -a --delete external/rpclib/$RPC_VERSION_FOLDER/include AirLib/deps/rpclib
rsync -a --delete MavLinkCom/include AirLib/deps/MavLinkCom
# NOTE: AirLib/src must stay in the plugin — UBT compiles AirLib sources as
# part of the AirSim module (upstream's old "rm -rf .../AirLib/src" breaks it).
rsync -a --delete AirLib Unreal/Plugins/AirSim/Source

# Sync the plugin into the environments bundled with this repo (BlocksV2, ...)
for d in Unreal/Environments/*; do
    [ -d "$d" ] || continue
    mkdir -p "$d/Plugins"
    rsync -a --delete Unreal/Plugins/AirSim "$d/Plugins/"
done

# Update all environment projects under ~/Documents/Unreal Projects (if any)
for d in ~/Documents/Unreal\ Projects/*; do
    [ -d "$d" ] || continue
    [ -L "${d%/}" ] && continue
    mkdir -p "$d/Plugins"
    rsync -a --delete Unreal/Plugins/AirSim/ "$d/Plugins/AirSim/"
done

echo ""
echo "=================================================================="
echo " Colosseum plugin built and synced into Unreal/Environments/*."
echo " Open Unreal/Environments/BlocksV2/BlocksV2.uproject and choose"
echo " 'Yes' when asked to rebuild the missing modules."
echo "=================================================================="

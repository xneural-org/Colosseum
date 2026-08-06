# Colosseum — UE 5.6.1 / Ubuntu 26.04 quick install

```bash
export UE_ROOT="$HOME/apps/UnrealEngine-5.6.1"   # adjust to your engine location

git clone -b ue561-ubuntu2604-fixes https://github.com/xneural-org/Colosseum.git
cd Colosseum
./setup.sh     # apt packages (sudo) + rpclib/Eigen/car-asset downloads
./build.sh     # uses UE_ROOT; auto-rebuilds rpclib against UE's sysroot if needed

# optional: precompile the editor modules headless (works over ssh)
"$UE_ROOT/Engine/Build/BatchFiles/Linux/Build.sh" BlocksV2Editor Linux Development "-project=$(pwd)/Unreal/Environments/BlocksV2/BlocksV2.uproject"

# launch — from a terminal in the desktop session (not ssh):
"$UE_ROOT/Engine/Binaries/Linux/UnrealEditor" "$(pwd)/Unreal/Environments/BlocksV2/BlocksV2.uproject"
# if asked "Rebuild missing modules?" -> Yes; first open compiles shaders; Play -> choose vehicle
```

Upstream docs (APIs, settings.json, vehicles): <https://codexlabsllc.github.io/Colosseum/>

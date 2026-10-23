#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK=${MAC_KERNEL_SDK:?Set MAC_KERNEL_SDK to the MacKernelSDK directory}
TOOLCHAIN=${DARWIN_TOOLCHAIN:?Set DARWIN_TOOLCHAIN to the Darwin toolchain bin directory}
OUT=${BUILD_OUTPUT:-$ROOT/build}
/bin/sh "$ROOT/scripts/prepare-mackernelsdk.sh" "$SDK"
mkdir -p "$OUT/objects"
cd "$ROOT"

# Compile the exact Sequoia PBXSourcesBuildPhase; its null entry is not a file.
python3 - <<'PY'
from pathlib import Path
import re, json
root = Path.cwd()
p = (root / 'itlwm.xcodeproj/project.pbxproj').read_text()
phase = re.search(r'AFFBDFD057C2402C908ECB89 /\* Sources \*/ = \{(.*?)\n\t\t\};', p, re.S).group(1)
files = []
inventory = {}
# Build output, deploy kits, backups and reference copies are not sources.
local = {'build', 'deploy-backups', 'deploy-staging', 'reference', 'tools'}
for path in root.rglob('*'):
    if path.is_file() and path.relative_to(root).parts[0] not in local:
        inventory.setdefault(path.name, []).append(path)
for name in re.findall(r'[A-F0-9]{24} /\* (.*?) in Sources \*/', phase):
    if name == '(null)':
        continue
    matches = inventory.get(name, [])
    assert len(matches) == 1, (name, matches)
    files.append(matches[0].relative_to(root).as_posix())
assert len(files) == 57, len(files)
(root / 'sources-sequoia.json').write_text(json.dumps(files, indent=2) + '\n')
PY

common=(-target x86_64-apple-macos15.2 -mkernel -fapple-kext
  -fno-sized-deallocation -fno-use-cxa-atexit
  -mllvm -disable-atexit-based-global-dtor-lowering
  -fstack-protector -fno-common -fno-builtin -mno-red-zone -mcmodel=kernel
  -nostdinc -D__PRIVATE_SPI__ -DKERNEL -DKERNEL_PRIVATE -DDRIVER_PRIVATE
  -DIEEE80211_STA_ONLY -DAIRPORT -DAIRPORT_WCL -DAIRPORT_VTD
  -DIO80211FAMILY_V2 -D__IO80211_TARGET=150200
  '-DITLWM_VERSION="1.0.0"' '-DGIT_COMMIT="be201-sequoia-dev"'
  -isystem "$SDK/Headers" -isystem "$(clang -print-resource-dir)/include"
  -I . -I itlwm -I itlwm/hal_iwx
  -I itl80211 -I itl80211/openbsd -I itl80211/linux -I include
  -I include/Airport -I AirportItlwm -include itlwm/PrivateSPI.pch
  -O1 -Wno-deprecated-register -Wno-multichar -Werror=return-type)

python3 - "$OUT" "${common[@]}" <<'PY'
import concurrent.futures, json, pathlib, subprocess, sys
out = pathlib.Path(sys.argv[1])
common = sys.argv[2:]
sources = json.load(open('sources-sequoia.json'))
assert len({pathlib.Path(s).stem for s in sources}) == len(sources)
def compile_source(source):
    stem = pathlib.Path(source).stem
    with (out / 'objects' / (stem + '.log')).open('w') as log:
        result = subprocess.run(['clang++', *common, '-x', 'c++', '-std=gnu++14',
            '-fno-exceptions', '-fno-rtti', '-c', source, '-o',
            str(out / 'objects' / (stem + '.o'))], stdout=log, stderr=log)
    return source, result.returncode
failed = []
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    for source, rc in pool.map(compile_source, sources):
        print(('FAIL' if rc else 'OK') + ' ' + source, flush=True)
        if rc:
            failed.append(source)
if failed:
    for source in failed:
        print((out / 'objects' / (pathlib.Path(source).stem + '.log')).read_text())
    sys.exit(1)
PY

cat > "$OUT/module.cpp" <<'EOF'
#include <mach/mach_types.h>
extern "C" {
extern kern_return_t _start(kmod_info_t *, void *);
extern kern_return_t _stop(kmod_info_t *, void *);
KMOD_EXPLICIT_DECL(com.zxystd.AirportItlwm, "1.0.0", _start, _stop)
__private_extern__ kmod_start_func_t *_realmain = 0;
__private_extern__ kmod_stop_func_t *_antimain = 0;
__private_extern__ int _kext_apple_cc = 1;
}
EOF
clang++ "${common[@]}" -std=gnu++14 -fno-exceptions -fno-rtti \
  -c "$OUT/module.cpp" -o "$OUT/objects/module.o"
"$TOOLCHAIN/x86_64-apple-darwin-ld" \
  -arch x86_64 -kext -undefined dynamic_lookup -macosx_version_min 15.2 \
  -o "$OUT/AirportItlwm" "$OUT"/objects/*.o "$SDK/Library/x86_64/libkmod.a"
printf 'Compiled 57 Sequoia sources and linked %s\n' "$OUT/AirportItlwm"

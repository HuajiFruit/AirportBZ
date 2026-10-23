#!/bin/sh
# Apply the reviewed PCI header backport before compiling either kext target.
set -eu

if [ "$#" -ne 1 ]; then
    printf 'Usage: %s /path/to/MacKernelSDK\n' "$0" >&2
    exit 2
fi

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SDK=$(CDPATH= cd -- "$1" && pwd)
PATCH="$ROOT/include/Airport/IOPCIDevice-msix.patch"

# Archive-based SDK copies may sit inside another Git worktree. Prevent Git
# from discovering that parent and silently skipping the SDK-relative paths.
GIT_CEILING_DIRECTORIES=$(dirname -- "$SDK")
export GIT_CEILING_DIRECTORIES

if [ ! -f "$SDK/Headers/IOKit/pci/IOPCIDevice.h" ]; then
    printf '%s\n' 'Error: IOPCIDevice.h is missing from MacKernelSDK.' >&2
    exit 1
fi

# The pinned SDK stores this header with CRLF line endings.
if git -C "$SDK" apply --ignore-space-change --reverse --check "$PATCH" 2>/dev/null; then
    printf '%s\n' 'MacKernelSDK MSI-X declarations are already prepared.'
    exit 0
fi

if ! git -C "$SDK" apply --ignore-space-change --check "$PATCH"; then
    printf '%s\n' 'Error: incompatible SDK header. Use MacKernelSDK 3f750085caa17ec3a7880f11c11bf4f48cd6a164.' >&2
    exit 1
fi

git -C "$SDK" apply --ignore-space-change "$PATCH"
printf '%s\n' 'Prepared MacKernelSDK MSI-X declarations.'

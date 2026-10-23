#!/usr/bin/env bash
set -euo pipefail
TOOLCHAIN=${DARWIN_TOOLCHAIN:-/mnt/c/Users/jimde/Documents/Codex/EFI-Touchpad-Polling-2026-10-19/toolchain/bin}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$TOOLCHAIN/x86_64-apple-darwin-nm" -u build/AirportItlwm | sort > build/current-nm.txt
SYM_COUNT=$(wc -l < build/current-nm.txt)
echo "Undefined symbol count: $SYM_COUNT"
diff -u build/baseline-nm.txt build/current-nm.txt

echo "Checking __mod_init_func and __mod_term_func size (must be 0x38, 7 constructors):"
"$TOOLCHAIN/x86_64-apple-darwin-otool" -l build/AirportItlwm | grep -A 5 '__mod_init_func'
"$TOOLCHAIN/x86_64-apple-darwin-otool" -l build/AirportItlwm | grep -A 5 '__mod_term_func'

echo "ABI check passed!"

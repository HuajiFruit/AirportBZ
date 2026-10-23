#!/bin/sh
# Collect AirportBZ diagnostics using tools included with macOS.
# No driver, EFI, NVRAM or network configuration changes; no uploads.
# Reports are private by default and may contain identifying information.

LC_ALL=C
export LC_ALL
umask 077

usage() {
    cat <<'EOF'
Usage: sudo /bin/sh scripts/collect-diagnostics.sh [options]
       /bin/sh scripts/collect-diagnostics.sh --props FILE

Options:
  --output DIR   Parent directory for a new report folder.
                 Default: diagnostics/ under the repository root.
  --kext PATH    Include Info.plist and the executable SHA-256 for this kext.
  --props FILE   Print a summary of an existing itlwm-properties.txt file.
                 Does not collect data, write files or require root/macOS.
  -h, --help     Show this help.

Collection requires macOS and root for kernel and Wi-Fi diagnostics.
Individual command failures are recorded in command-status.txt.
Reports may contain SSIDs, MAC/IP addresses and machine identifiers.
Review reports before sharing. Nothing is uploaded automatically.
EOF
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

OUTPUT_PARENT=''
KEXT=''
PROPS=''
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output|--kext|--props)
            [ "$#" -ge 2 ] && [ -n "$2" ] || fail "$1 requires a value."
            case "$1" in
                --output) OUTPUT_PARENT=$2 ;;
                --kext) KEXT=$2 ;;
                --props) PROPS=$2 ;;
            esac
            shift 2
            ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown option: $1. Use --help for usage." ;;
    esac
done

# Property snapshots are tab-separated name/value pairs. Missing values are
# reported as unavailable, never treated as zero or proof that a check passed.
prop() {
    awk -F '\t' -v key="$1" '$1 == key { print $2; exit }' "$PROPS"
}

show() {
    value=$(prop "$1")
    [ -n "$value" ] || value='(not recorded)'
    printf '  %-31s %s\n' "$1" "$value"
}

group() {
    printf '\n-- %s --\n' "$1"
    shift
    for property in "$@"; do
        show "$property"
    done
}

summary() {
    printf '%s\n' 'AirportBZ diagnostic summary'
    printf 'Property snapshot: %s\n' "$PROPS"
    printf '%s\n' 'Values describe the captured state; counters may span multiple connections.'
    printf '%s\n' 'Missing properties do not establish success or failure.'
    if ! awk -F '\t' '$1 ~ /^Itlwm/ { found=1; exit } END { exit !found }' "$PROPS"; then
        printf '\n%s\n' 'No Itlwm properties found. Check loaded kexts and the PCI registry.'
    fi
    group 'Driver and firmware startup' \
        ItlwmStartupRevision ItlwmStartupStage ItlwmStartupFailure \
        ItlwmStartupError ItlwmBootMsixMode ItlwmMsixSetupStatus \
        ItlwmBootIrqCallbacks ItlwmBootIrqFilterCalls \
        ItlwmBootMsixFhCauseBits ItlwmBootMsixHwCauseBits \
        ItlwmBootParsedAlive ItlwmFirmwareAliveValid ItlwmBootAlivePollHits \
        ItlwmReadyPosted ItlwmWclLastReady ItlwmInitStep ItlwmInitErr
    printf '%s\n' '  MSI-X mode: 1=MSI-X. ParsedAlive: 1=firmware ALIVE notification parsed.'
    group 'PNVM' \
        ItlwmPnvmFailStep ItlwmPnvmDescFound ItlwmPnvmDescLength \
        ItlwmPnvmInflateOk ItlwmPnvmInflatedLength ItlwmPnvmChunkCount \
        ItlwmPnvmTotalSize ItlwmPnvmFragmented ItlwmPnvmHwMatch \
        ItlwmPnvmNotifyStatus ItlwmPnvmReadError
    group 'Scanning' \
        ItlwmWclScanReq ItlwmWclScanDonePosted ItlwmWclScanResult \
        ItlwmScanError ItlwmScanChannels ItlwmScanMs ItlwmScanNodes \
        ItlwmWclBeacons ItlwmWclBeaconsPosted ItlwmWclBeaconsDropped \
        ItlwmWclScanRejected ItlwmWclScanRejectReason ItlwmWclScanRejectState \
        ItlwmWclScanRunStarted ItlwmWclScanQueued \
        ItlwmWclScanQueueDepthMax ItlwmWclScanQueueFailed \
        ItlwmScanAwayMs ItlwmScanSuspendTU ItlwmScanMaxOutTU
    printf '%s\n' '  ScanMs: last scan duration in milliseconds, including background scans.'
    group 'Joining and association' \
        ItlwmWclAssocCalls ItlwmWclAssocDecode ItlwmWclAssocAuthClass \
        ItlwmWclJoinStarts ItlwmWclJoinDeferred ItlwmWclJoinAbortOffline \
        ItlwmBssSeen ItlwmBssOk ItlwmBssDesFound ItlwmBssDesFail \
        ItlwmWclJoinReq ItlwmWclJoinResult ItlwmWclJoinReason \
        ItlwmWclJoinDriverStatus ItlwmNewState ItlwmFirmwareMldApi \
        ItlwmMldAssocStep ItlwmMldAssocErr ItlwmMldMgmtQueue \
        ItlwmMldAuthChan ItlwmMldAuthChanFlags \
        ItlwmMccCode ItlwmMccStatus ItlwmMccSource ItlwmMccChannels
    printf '%s\n' '  MldAssocStep: 7=authentication ready, 16=associated, 17=RUN stopped.'
    group 'Authentication, queues and teardown' \
        ItlwmSessProtTu ItlwmSessProtNotifs ItlwmSessProtStatus \
        ItlwmSessProtStart ItlwmSessProtId \
        ItlwmTxResp ItlwmTxRespStatus ItlwmTxRespRetries ItlwmTxRespRts \
        ItlwmTxRespRate ItlwmTxRespQid ItlwmTxRespFrames ItlwmTxRespDrop \
        ItlwmRxAuth ItlwmRxAuthSeq ItlwmRxAuthStatus \
        ItlwmMldKeys ItlwmMldKeyErr ItlwmMldRxBa ItlwmMldRxBaErr \
        ItlwmMldDataQueues ItlwmMldTxqErr ItlwmMldRxBaRemoved \
        ItlwmMldKeyRemoved ItlwmTxPreAuthMgmtQ ItlwmMldLeaveFrames \
        ItlwmTxNoQueueDrop ItlwmEapolHeld ItlwmEapolReplayed \
        ItlwmMacChangeNoRestart ItlwmMacReconfigSet
    printf '%s\n' '  Session protection is reported in TU (1 TU = 1.024 ms).'
    printf '%s\n' '  TX response status low byte: 0x01=success, 0x82=no ACK.'
    group 'Firmware errors and gate waits' \
        ItlwmFwErrors ItlwmFwErrorId ItlwmFwErrorData1 ItlwmFwErrorCmd \
        ItlwmInitRetries ItlwmGateStallMaxMs ItlwmGateStallWait ItlwmGateStalls \
        ItlwmPhyErr ItlwmRlcErr ItlwmLastCmdId ItlwmLastCmdErr
    printf '%s\n' '  GateStallMaxMs: longest recorded gate sleep, in milliseconds.'
    printf '%s\n' '  Last host command alone does not establish the cause of a firmware error.'
    printf '\n%s\n' '-- All captured properties (including additional probes) --'
    cat "$PROPS"
}

if [ -n "$PROPS" ]; then
    [ -z "$OUTPUT_PARENT" ] && [ -z "$KEXT" ] || \
        fail '--props cannot be combined with --output or --kext.'
    [ -f "$PROPS" ] && [ -r "$PROPS" ] || fail "Cannot read property file: $PROPS"
    summary
    exit 0
fi

[ "$(uname -s)" = 'Darwin' ] || fail 'Collection requires macOS. Use --props for offline summaries.'
[ "$(id -u)" = '0' ] || fail 'Run this script with sudo to collect diagnostics.'
if [ -n "$KEXT" ]; then
    [ -r "$KEXT/Contents/Info.plist" ] && \
        [ -r "$KEXT/Contents/MacOS/AirportItlwm" ] || fail "Not a readable AirportItlwm bundle: $KEXT"
fi

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 1
[ -n "$OUTPUT_PARENT" ] || OUTPUT_PARENT="$SCRIPT_DIR/../diagnostics"
# New parent directories must remain traversable after sudo; mktemp below
# creates the actual report folder privately under the original umask.
(umask 022; mkdir -p "$OUTPUT_PARENT") || fail "Cannot create output directory: $OUTPUT_PARENT"
OUTPUT_PARENT=$(CDPATH='' cd -- "$OUTPUT_PARENT" && pwd) || exit 1
STAMP=$(date '+%Y%m%d-%H%M%S')
OUT=$(mktemp -d "$OUTPUT_PARENT/AirportBZ-$STAMP.XXXXXX") || fail 'Cannot create report folder.'
printf 'Collecting diagnostics into:\n%s\n' "$OUT"
printf '%s\n' 'Wi-Fi profiling and log queries may take a few minutes.'
printf 'file\texit_status\n' > "$OUT/command-status.txt"
FAILED=0

capture() {
    report=$1
    shift
    printf 'Collecting %s ...\n' "$report"
    "$@" > "$OUT/$report" 2>&1
    status=$?
    printf '%s\t%s\n' "$report" "$status" >> "$OUT/command-status.txt"
    if [ "$status" -ne 0 ]; then
        FAILED=$((FAILED + 1))
    fi
}

# Save volatile evidence before the slower profile and unified-log queries.
capture kernel-buffer.txt /sbin/dmesg
capture pci-registry-early.txt /usr/sbin/ioreg -p IOService -r -c IOPCIDevice -l -w0
capture system-version.txt /usr/bin/sw_vers
capture kernel-version.txt /usr/bin/uname -a
capture boot-session.txt /usr/sbin/sysctl kern.bootsessionuuid kern.boottime kern.osversion kern.bootargs
capture kexts-loaded.txt /usr/bin/kmutil showloaded
capture hardware-ports.txt /usr/sbin/networksetup -listallhardwareports
capture ifconfig.txt /sbin/ifconfig -a
capture airport-profile.txt /usr/sbin/system_profiler SPAirPortDataType
capture wdutil-info.txt /usr/bin/wdutil info
capture pci-registry.txt /usr/sbin/ioreg -p IOService -r -c IOPCIDevice -l -w0
capture acpi-registry.txt /usr/sbin/ioreg -p IOACPIPlane -l -w0

# Use the early snapshot so profiling scans do not change the summarized state.
# Preserve string, integer, Boolean and binary property values as text.
PROPS="$OUT/itlwm-properties.txt"
awk '
    /"Itlwm[A-Za-z0-9]+"[[:space:]]*=/ {
        line=$0
        sub(/^[^"]*"/, "", line)
        name=line
        sub(/".*/, "", name)
        sub(/^[^"]*"[[:space:]]*=[[:space:]]*/, "", line)
        if (line ~ /^".*"$/) {
            sub(/^"/, "", line)
            sub(/"$/, "", line)
        }
        print name "\t" line
    }
' "$OUT/pci-registry-early.txt" | sort -u > "$PROPS"
awk '/"Itlwm(Lmac|Umac)Error[A-Za-z0-9]*"[[:space:]]*=/' \
    "$OUT/pci-registry-early.txt" > "$OUT/firmware-error-tables.txt"

if [ -n "$KEXT" ]; then
    capture driver-info.txt /usr/bin/plutil -p "$KEXT/Contents/Info.plist"
    capture driver-sha256.txt /usr/bin/shasum -a 256 "$KEXT/Contents/MacOS/AirportItlwm"
fi

capture wifi-driver-log.txt /usr/bin/log show --last 2h --style syslog --info --debug \
    --predicate 'eventMessage CONTAINS[c] "itlwm" OR eventMessage CONTAINS[c] "iwx" OR eventMessage CONTAINS[c] "MSI-X" OR eventMessage CONTAINS[c] "IO80211Family"'
capture wifi-daemon-log.txt /usr/bin/log show --last 15m --style syslog --info --debug \
    --predicate 'process == "airportd" OR process == "WiFiAgent" OR process == "wifip2pd" OR process CONTAINS "System Settings" OR process CONTAINS "WiFiSettings" OR subsystem BEGINSWITH "com.apple.wifi"'

{
    date '+Collected: %Y-%m-%d %H:%M:%S %z'
    printf 'Commands with nonzero exit status: %s (see command-status.txt)\n\n' "$FAILED"
    summary
} > "$OUT/summary.txt"

# Let the invoking user open the private report folder after sudo exits.
case "${SUDO_UID:-}:${SUDO_GID:-}" in
    *[!0-9:]*|:*|*:) ;;
    *) /usr/sbin/chown -R "$SUDO_UID:$SUDO_GID" "$OUT" || \
        printf '%s\n' 'Could not change report ownership; use sudo to read the folder.' >&2 ;;
esac

printf '\nReports saved to:\n%s\n' "$OUT"
printf '%s\n' 'Start with summary.txt and command-status.txt.'
if [ "$FAILED" -gt 0 ]; then
    printf 'Collection is partial: %s command(s) failed. Available reports were kept.\n' "$FAILED"
fi
printf '%s\n' 'Review identifying information before sharing. Nothing was uploaded.'

# AirportBZ

[English](README.md) | [简体中文](README_CN.md)

Experimental native macOS Wi-Fi driver for Intel BE201, with an untested BE200 path.

AirportBZ is based on OpenIntelWireless's `itlwm` and the AirPort WCL front end from
`laobamac/itlwm`. It connects to the system `IO80211Family` / `IOSkywalkFamily` stack,
so you can scan and join networks from the macOS Wi-Fi menu without HeliPort.
The output bundle is still named **`AirportItlwm.kext`**.

**BE201 has been tested on Sequoia. BE200 and Tahoe have only been compile-checked.**
The Wi-Fi 7 hardware name does not imply support for Wi-Fi 7 features.

## Compatibility

### Hardware

| Adapter | PCI ID | Status |
| --- | --- | --- |
| Intel BE201 (BZ MAC) | `8086:7740` | Supports scanning, open/WPA2 connections, DHCP and network switching. |
| Intel BE200 (GL MAC) | `8086:272B` | Device configuration and firmware included; never run on hardware. Requires GL-C0 / FM-C0 stepping. |
| Intel BE202 | — | Unsupported; this project has no verified device/firmware mapping. |
| AX200, AX210 and older Intel adapters | — | Unsupported by this build; use the upstream [OpenIntelWireless project](https://github.com/OpenIntelWireless/itlwm). |

The packaged PCI match contains only BE201 and BE200. Some shared AX code remains in
the HAL, but this repository includes only the API 92 firmware and PNVM files for
`bz-b0-fm-c0` and `gl-c0-fm-c0`. A PCI match alone does not bypass stepping checks.

### macOS

| System | Status |
| --- | --- |
| Sequoia 15.2+ (`Darwin 24.2.0–24.99.99`), x86_64 | Primary target; BE201 hardware support. |
| Tahoe 26, x86_64 | Separate `AirportItlwm-Tahoe` target, compile-checked only. No hardware validation. |
| Sequoia before 15.2, Sonoma and earlier | Unsupported. The Sequoia build rejects kernels outside its supported range. |

The Sequoia binary and the installation steps below are for Sequoia only. Changing
`MinKernel` or `MaxKernel` does not make that binary compatible with Tahoe.

## What works, and what still needs work

The following status applies to BE201 on Sequoia:

| Feature | Current status |
| --- | --- |
| Native Wi-Fi interface and scanning | Supported through the AirPort / Skywalk front end. |
| Open networks and WPA2-Personal (PSK/CCMP) | Supported, including DHCP. |
| Switching between networks | User-initiated switching is supported; seamless roaming is unverified. |
| WPA3-Personal (SAE) and protected management frames (PMF) | Unsupported by this driver. WPA3-only and mandatory-PMF networks cannot be joined. |
| WPA-Enterprise / 802.1X | Not tested. |
| 802.11ax (HE) | Experimental; enabled only with the `itlwm_he=1` boot argument. Default operation advertises a/b/g/n/ac. |
| 6 GHz, 320 MHz channels and MLO | Unsupported. |
| AWDL / AirDrop | Unsupported. |

## Installation with OpenCore (Sequoia)

Back up your EFI and have a complete Sequoia `AirportItlwm.kext` bundle ready.

1. **Copy the driver.** Place the entire `AirportItlwm.kext` bundle in `EFI/OC/Kexts/`.
2. **Add it to your boot configuration.** Open `EFI/OC/config.plist` in your usual
   OpenCore configuration editor. Find the driver list (`Kernel → Add`) and add
   `AirportItlwm.kext`. If it is already listed, edit that entry.
3. **Enable the new driver and disable the old one.** Check `Enabled` for
   `AirportItlwm.kext`. If `itlwm.kext` is also listed, uncheck its `Enabled` setting.
   **These two drivers must never be enabled together.**
4. **Set the loading range.** Set `MinKernel` to `24.2.0` and `MaxKernel` to `24.99.99`.
   These are Darwin kernel versions; they limit loading to Sequoia 15.2 and later
   releases within the 15.x series.
5. **Save and reboot.** Once in Sequoia, choose a network from the Wi-Fi menu or
   **System Settings > Wi-Fi**.

<details>
<summary>If your editor asks you to enter driver paths manually</summary>

Use these values in the `AirportItlwm.kext` entry. `BundlePath` starts inside
`EFI/OC/Kexts/`; the executable and plist paths start inside the kext bundle.

| Field | Value |
| --- | --- |
| `BundlePath` (relative to `EFI/OC/Kexts/`) | `AirportItlwm.kext` |
| `ExecutablePath` (inside the bundle) | `Contents/MacOS/AirportItlwm` |
| `PlistPath` (inside the bundle) | `Contents/Info.plist` |
| `Arch` (processor architecture) | `x86_64` |

Field definitions: [OpenCore configuration reference](https://github.com/acidanthera/OpenCorePkg/blob/master/Docs/Configuration.tex).

</details>

This build uses the system wireless frameworks. It does not require
`IO80211FamilyLegacy`, replacement or blocking of native `IOSkywalkFamily`,
OCLP Modern Wireless patches, or HeliPort.

For experimental HE support, add `itlwm_he=1` to OpenCore's `boot-args`. This enables
the driver's 802.11ax path; it does not add WPA3, 6 GHz or MLO support.

## Building from source

The verified command-line environment is **WSL Ubuntu-26.04 with clang 21**. You need
Python 3, Bash, MacKernelSDK at commit
`3f750085caa17ec3a7880f11c11bf4f48cd6a164`, and a Darwin toolchain containing
`x86_64-apple-darwin-ld`, `x86_64-apple-darwin-nm` and
`x86_64-apple-darwin-otool`. These dependencies are not bundled in this repository.

Run from the repository root, replacing the two dependency paths:

```bash
export MAC_KERNEL_SDK="/absolute/path/to/MacKernelSDK"
export DARWIN_TOOLCHAIN="/absolute/path/to/darwin-toolchain/bin"

# Required on a fresh checkout and whenever firmware changes.
python3 scripts/zlib_compress_fw.py include/FwBinary.cpp firmware-bz92

# Build the Sequoia executable.
BUILD_OUTPUT="$PWD/build" bash scripts/build-sequoia-bz92.sh

# Exercise selected production functions without hardware.
python3 scripts/test-bz-boot-checks.py
```

The build script reads the 57 source files from the `AirportItlwm-Sequoia` Sources
phase in `itlwm.xcodeproj` and writes `build/AirportItlwm`. This is the executable;
the script does not assemble a complete `.kext` bundle. It compiles for x86_64 /
macOS 15.2 with `AIRPORT_WCL`, `AIRPORT_VTD`, `IO80211FAMILY_V2` and
`__IO80211_TARGET=150200`. `include/FwBinary.cpp` is generated and is not tracked.

The Xcode project also includes `AirportItlwm-Tahoe` and a `fw_gen` step.
The script above builds Sequoia only. Xcode and CI builds are unverified.
When launching WSL from Git Bash, set
`MSYS_NO_PATHCONV=1`; keep shell scripts LF-terminated.

### ABI and packaging checks

After a Sequoia build, compare its undefined-symbol **set**, not just its count,
with the previous BZ-only Sequoia baseline. The expected baseline is 954 imports, with
`__mod_init_func` and `__mod_term_func` each sized `0x38` (7 entries). Changes require
an explanation in the change description.

Tahoe uses different Apple interface signatures, so the Sequoia import set is
not a Tahoe baseline.

With `DARWIN_TOOLCHAIN` set, run `bash scripts/check_abi.sh` to compare
`build/AirportItlwm` against `build/baseline-nm.txt`, a sorted `nm -u` listing
from your reference build. The baseline is not included in a fresh checkout.
The script diffs imports and prints the constructor/destructor sections;
inspect their sizes as well.

To make a loadable bundle, the executable belongs at
`AirportItlwm.kext/Contents/MacOS/AirportItlwm`, alongside a resolved
`Contents/Info.plist` based on `AirportItlwm/WCL/Sequoia-Info.plist`. The source plist
contains Xcode variables and must not be copied unchanged.

The host tests use ASan/UBSan to exercise selected HAL error paths, interrupt
handoff and mask restoration. Passing them does not prove firmware boot,
association, connectivity or compatibility on another machine.

## Diagnostics and contributing

The [diagnostic collector](scripts/collect-diagnostics.sh) runs on macOS
using built-in tools, without Python or a network connection. From the repository
root, run it after reproducing the problem:

```sh
sudo /bin/sh scripts/collect-diagnostics.sh
```

Reports are saved in a new folder under `diagnostics/`, which Git ignores.
Start with `summary.txt` and `command-status.txt`. The collector saves driver
properties, loaded kext information, network interfaces, the kernel buffer and
recent Wi-Fi logs. It does not change EFI, NVRAM or network settings, or upload
anything. The AirPort profile command may trigger a Wi-Fi scan.

Use `--output /path/to/reports` to choose another parent directory, or
`--kext /path/to/AirportItlwm.kext` to include that bundle's plist and executable
SHA-256. To summarize an existing property snapshot without collecting again:

```sh
/bin/sh scripts/collect-diagnostics.sh --props /path/to/itlwm-properties.txt
```

Reports can contain SSIDs, MAC/IP addresses and machine identifiers. Review them
before sharing and attach only the files needed to explain the issue.

Runtime diagnostics are published as `Itlwm*` properties on the Wi-Fi
`IOPCIDevice` in IORegistry. When reporting a problem, include the adapter's PCI
and subsystem IDs, macOS version, `ItlwmStartupRevision`, boot arguments, network
security mode and the steps that reproduce it. Useful properties include
`ItlwmInitStep`, `ItlwmMldAssocStep`, `ItlwmMldAssocErr`, `ItlwmFwErrors`,
`ItlwmFwErrorId` and `ItlwmFwErrorCmd`.

Kernel messages alone may be incomplete: `XYLog` writes to the kernel ring buffer,
which can be overwritten quickly. Check IORegistry properties and the Wi-Fi
daemon log as well. Missing properties do not by themselves indicate success
or failure.

| Path | Purpose |
| --- | --- |
| `AirportItlwm/`, `AirportItlwm/WCL/` | Native AirPort / Skywalk front end and scan/join messaging. |
| `itlwm/hal_iwx/` | Device initialization, firmware commands and TX/RX paths. |
| `itl80211/` | net80211 and compatibility code, including EAPOL handling. |
| `include/`, `include/Airport/` | Firmware wrapper and private Apple interface headers. |
| `firmware-bz92/` | BE201 and BE200 API 92 firmware and PNVM. |
| `scripts/` | Build, firmware generation, diagnostics and host checks. |

When changing firmware commands, compare their layouts and ordering against
Linux v6.11 iwlwifi, which targets BZ firmware API 92. Keep diagnostic property
names stable and include relevant host checks with driver changes.

## License and credits

Driver source is distributed under [GPLv2](LICENSE), with existing file-level
notices retained. Intel firmware has its own [redistribution license](LICENCE.bz-firmware).

Thanks to [OpenIntelWireless](https://github.com/OpenIntelWireless/itlwm) for itlwm,
[laobamac](https://github.com/laobamac/itlwm) for the native WCL front end, and the
OpenBSD net80211 and Linux iwlwifi contributors whose work this port builds on.

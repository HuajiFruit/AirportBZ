# AirportBZ

[English](README.md) | [简体中文](README_CN.md)

面向 Intel BE201 的实验性 macOS 原生 Wi-Fi 驱动，同时包含尚未经真机验证的 BE200 适配。

AirportBZ 基于 OpenIntelWireless 的 `itlwm` 和 `laobamac/itlwm` 的 AirPort WCL 前端，
接入系统自带的 `IO80211Family` / `IOSkywalkFamily`，可以直接通过 macOS Wi-Fi 菜单扫描和连接网络，
无需 HeliPort。驱动包名称仍为 **`AirportItlwm.kext`**。

**BE201 已在 Sequoia 上进行真机测试；BE200 和 Tahoe 目前仅通过编译检查。**
网卡型号中的“Wi-Fi 7”不代表本驱动已支持 Wi-Fi 7 的各项功能。

## 兼容性

### 网卡

| 网卡 | PCI ID | 当前状态 |
| --- | --- | --- |
| Intel BE201（BZ MAC） | `8086:7740` | 支持扫描、开放网络及 WPA2 连接、DHCP 和网络切换。 |
| Intel BE200（GL MAC） | `8086:272B` | 已包含设备配置和固件，尚未在真机上运行。要求 GL-C0 / FM-C0 步进。 |
| Intel BE202 | — | 不支持；本项目尚无经过验证的设备与固件对应关系。 |
| AX200、AX210 及更早的 Intel 网卡 | — | 本构建不支持，请使用上游 [OpenIntelWireless 项目](https://github.com/OpenIntelWireless/itlwm)。 |

驱动包的 PCI 匹配列表仅包含 BE201 和 BE200。HAL 中仍保留部分共用的 AX 代码，
但仓库只包含 `bz-b0-fm-c0` 和 `gl-c0-fm-c0` 的 API 92 固件及 PNVM 文件。
PCI ID 匹配后，驱动仍会检查硬件步进。

### macOS

| 系统 | 当前状态 |
| --- | --- |
| Sequoia 15.2+（`Darwin 24.2.0–24.99.99`），x86_64 | 主要目标平台，已适配 BE201 真机。 |
| Tahoe 26，x86_64 | 独立的 `AirportItlwm-Tahoe` 目标，仅通过编译检查，尚无真机验证。 |
| Sequoia 15.2 之前的版本、Sonoma 及更早系统 | 不支持。Sequoia 构建会拒绝支持范围之外的内核。 |

Sequoia 二进制文件和下方的安装步骤仅适用于 Sequoia。
修改 `MinKernel` 或 `MaxKernel` 并不能让该二进制文件兼容 Tahoe。

## 功能状态与已知问题

以下功能状态适用于 Sequoia 上的 BE201：

| 功能 | 当前状态 |
| --- | --- |
| 原生 Wi-Fi 界面与扫描 | 支持，通过 AirPort / Skywalk 前端接入。 |
| 开放网络与 WPA2-Personal（PSK/CCMP） | 支持连接和 DHCP。 |
| 网络切换 | 支持用户主动切换网络；无缝漫游尚未验证。 |
| WPA3-Personal（SAE）与管理帧保护（PMF） | 本驱动不支持。无法连接纯 WPA3 网络或强制要求 PMF 的网络。 |
| WPA-Enterprise / 802.1X | 尚未测试。 |
| 802.11ax（HE） | 实验性功能，仅在添加 `itlwm_he=1` 启动参数后开启。默认向系统报告 a/b/g/n/ac 能力。 |
| 6 GHz、320 MHz 信道与 MLO | 不支持。 |
| AWDL / AirDrop（隔空投送） | 不支持。 |

## 使用 OpenCore 安装（Sequoia）

先备份 EFI，再准备好完整的 Sequoia 版 `AirportItlwm.kext` 驱动包。

1. **放入驱动。** 将整个 `AirportItlwm.kext` 放到 `EFI/OC/Kexts/` 文件夹。
2. **把驱动加入启动配置。** 用你平时编辑 OpenCore 配置的工具打开 `EFI/OC/config.plist`，
   找到驱动列表（`Kernel → Add`），添加 `AirportItlwm.kext`。如果已经有这一项，直接修改它即可。
3. **启用新驱动，停用旧驱动。** 勾选 `AirportItlwm.kext` 的“启用”（`Enabled`）。
   如果列表中还有 `itlwm.kext`，取消它的勾选。**这两个驱动不能同时启用。**
4. **设置加载范围。** 将新驱动的 `MinKernel` 填为 `24.2.0`，`MaxKernel` 填为 `24.99.99`。
   这是 Darwin 内核版本范围，用来限制驱动只在 Sequoia 15.2 及之后的 15.x 系统中加载。
5. **保存并重启。** 进入 Sequoia 后，点击菜单栏的 Wi-Fi 图标，或打开**系统设置 > Wi-Fi**，选择网络连接。

<details>
<summary>配置工具要求手动填写驱动路径时，填什么？</summary>

在 `AirportItlwm.kext` 这一项中填写以下内容。`BundlePath` 从 `EFI/OC/Kexts/` 目录内算起，
可执行文件和 plist 的路径则从 kext 包内算起。

| 字段 | 填写内容 |
| --- | --- |
| `BundlePath`（驱动包名，相对于 `EFI/OC/Kexts/`） | `AirportItlwm.kext` |
| `ExecutablePath`（包内可执行文件） | `Contents/MacOS/AirportItlwm` |
| `PlistPath`（包内配置文件） | `Contents/Info.plist` |
| `Arch`（处理器架构） | `x86_64` |

字段含义见 [OpenCore 配置参考](https://github.com/acidanthera/OpenCorePkg/blob/master/Docs/Configuration.tex)。

</details>

本构建使用系统自带的无线框架，无需注入 `IO80211FamilyLegacy`、替换或屏蔽系统的
`IOSkywalkFamily`，也无需使用 OCLP Modern Wireless 补丁或运行 HeliPort。

如需尝试 HE，可在 OpenCore 的 `boot-args` 中添加 `itlwm_he=1`。
这个参数开启驱动的 802.11ax 路径，不会增加 WPA3、6 GHz 或 MLO 支持。

## 从源码构建

已验证的命令行环境为 **WSL Ubuntu-26.04，使用 clang 21**。
需要 Python 3、Bash、Git、固定到提交 `3f750085caa17ec3a7880f11c11bf4f48cd6a164` 的 MacKernelSDK，
以及包含 `x86_64-apple-darwin-ld`、`x86_64-apple-darwin-nm` 和
`x86_64-apple-darwin-otool` 的 Darwin 工具链。仓库不附带这些构建依赖。

构建入口会自动将项目附带的 MSI-X 头文件补丁应用到 MacKernelSDK，
在对应的预留虚函数槽中补充 Apple 的 `IOPCIDevice::configureInterrupts` 声明。
请使用可写的 SDK 目录；已经应用过补丁的头文件不会重复修改。

在仓库根目录运行以下命令，并将两个依赖路径替换为实际路径。
首次克隆以及固件发生变化后，都需要先生成固件封装文件：

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

构建脚本从 `itlwm.xcodeproj` 中 `AirportItlwm-Sequoia` 目标的 Sources 阶段读取 57 个源文件，
输出 `build/AirportItlwm`。这是可执行文件，脚本不会组装完整的 `.kext` 驱动包。
编译目标为 x86_64 / macOS 15.2，使用
`AIRPORT_WCL`、`AIRPORT_VTD`、`IO80211FAMILY_V2` 和 `__IO80211_TARGET=150200`。
`include/FwBinary.cpp` 是生成文件，不纳入版本控制。

Xcode 工程还包含 `AirportItlwm-Tahoe` 目标和 `fw_gen` 步骤。上面的脚本只构建 Sequoia，
Xcode 和 CI 构建尚未验证。
从 Git Bash 调用 WSL 时，请设置 `MSYS_NO_PATHCONV=1`；Shell 脚本需保持 LF 换行符。

### ABI 与打包检查

每次构建 Sequoia 版本后，应将未定义符号的**完整集合**与此前的 BZ 专用 Sequoia 构建基线进行比较，不能只比较数量。
预期基线为 954 个导入符号，`__mod_init_func` 和 `__mod_term_func` 的大小均为 `0x38`，
各包含 7 个条目。如果这些内容发生变化，应在变更说明中写明原因。

Tahoe 使用不同的 Apple 接口签名，不能把 Sequoia 的导入符号集合用作 Tahoe 的基线。

设置好 `DARWIN_TOOLCHAIN` 后，运行 `bash scripts/check_abi.sh`，将 `build/AirportItlwm`
与 `build/baseline-nm.txt` 比较。基线文件应来自参考构建的 `nm -u` 输出，并事先排序；
新克隆的仓库不包含这个文件。脚本会比较导入符号并打印构造函数、析构函数段，仍需检查段大小。

制作可加载的驱动包时，可执行文件应放在
`AirportItlwm.kext/Contents/MacOS/AirportItlwm`，同时需要根据
`AirportItlwm/WCL/Sequoia-Info.plist` 生成并填好 `Contents/Info.plist`。
源码中的 plist 含有 Xcode 变量，不能原样复制使用。

主机测试通过 ASan/UBSan 检查部分 HAL 错误路径、中断交接和掩码恢复逻辑。
测试通过并不能证明固件能够启动、网络能够关联或联网，也不能证明驱动在另一台机器上兼容。

## 诊断与参与开发

项目提供[诊断脚本](scripts/collect-diagnostics.sh)，使用 macOS 自带工具，
不依赖 Python 或网络连接。复现问题后，在项目根目录运行：

```sh
sudo /bin/sh scripts/collect-diagnostics.sh
```

报告保存在 `diagnostics/` 下新建的文件夹中，该目录已加入 Git 忽略列表。
可以先查看 `summary.txt` 和 `command-status.txt`。脚本会收集驱动属性、已加载的 kext、
网络接口、内核缓冲区及近期 Wi-Fi 日志，不会修改 EFI、NVRAM 或网络配置，也不会上传内容。
其中的 AirPort 配置查询可能触发一次 Wi-Fi 扫描。

使用 `--output /path/to/reports` 可指定保存报告的父目录；
使用 `--kext /path/to/AirportItlwm.kext` 可额外记录指定驱动包的 plist 和可执行文件 SHA-256。
如需重新查看已有属性快照的摘要，无需再次采集：

```sh
/bin/sh scripts/collect-diagnostics.sh --props /path/to/itlwm-properties.txt
```

报告可能包含 Wi-Fi 名称、MAC/IP 地址和机器标识。分享前请检查内容，仅附上说明问题所需的文件。

运行时诊断信息以 `Itlwm*` 属性的形式发布在 IORegistry 中无线网卡的 `IOPCIDevice` 节点上。
报告问题时，请提供网卡 PCI ID 与子系统 ID、macOS 版本、`ItlwmStartupRevision`、启动参数、
网络安全模式及复现步骤。常用属性包括 `ItlwmInitStep`、`ItlwmMldAssocStep`、
`ItlwmMldAssocErr`、`ItlwmFwErrors`、`ItlwmFwErrorId` 和 `ItlwmFwErrorCmd`。

仅靠内核日志可能无法还原问题：`XYLog` 写入内核环形缓冲区，内容可能很快被覆盖。
还应结合 IORegistry 属性与 Wi-Fi 守护进程日志判断。某个属性缺失本身并不能说明成功或失败。

| 路径 | 用途 |
| --- | --- |
| `AirportItlwm/`、`AirportItlwm/WCL/` | 原生 AirPort / Skywalk 前端及扫描、连接消息处理。 |
| `itlwm/hal_iwx/` | 设备初始化、固件命令及收发路径。 |
| `itl80211/` | net80211 和兼容层代码，包括 EAPOL 处理。 |
| `include/`、`include/Airport/` | 固件封装及 Apple 私有接口头文件。 |
| `firmware-bz92/` | BE201 和 BE200 的 API 92 固件及 PNVM。 |
| `scripts/` | 构建、固件生成、诊断和主机检查脚本。 |

修改固件命令时，请对照面向 BZ 固件 API 92 的 Linux v6.11 iwlwifi 实现，检查命令布局与顺序。
保持诊断属性名称稳定，并为驱动变更提供相应的主机检查结果。

## 许可证与鸣谢

驱动源码采用 [GPLv2](LICENSE)，并保留各源文件原有的版权与许可声明。
Intel 固件遵循单独的[再分发许可证](LICENCE.bz-firmware)。

感谢 [OpenIntelWireless](https://github.com/OpenIntelWireless/itlwm) 提供 itlwm，
感谢 [laobamac](https://github.com/laobamac/itlwm) 提供原生 WCL 前端，
也感谢本移植所依赖的 OpenBSD net80211 和 Linux iwlwifi 贡献者。

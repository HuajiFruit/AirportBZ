# Changelog

## [v1.0.0] - 2026-10-23

### Initial release

First public release of AirportBZ, an experimental native macOS Wi-Fi driver
distributed as `AirportItlwm.kext`. Networks can be scanned and joined through
the macOS Wi-Fi menu without HeliPort.

#### Platforms

| macOS / architecture | Adapter | Status |
| --- | --- | --- |
| Sequoia 15.2+ (`Darwin 24.2.0–24.99.99`), x86_64 | Intel BE201 (`8086:7740`) | Primary supported platform; verified on hardware. |
| Sequoia 15.2+ (`Darwin 24.2.0–24.99.99`), x86_64 | Intel BE200 (`8086:272B`) | Device support and firmware included; compile-checked only. Requires GL-C0 / FM-C0 stepping. |
| Tahoe 26, x86_64 | Intel BE201 / BE200 | Separate build target; compile-checked only, with no hardware validation. |

BE201 on Sequoia is the only hardware-validated combination. BE200 and Tahoe
runtime compatibility remains unverified. Use the build matching your macOS
version. Earlier macOS versions and other Intel Wi-Fi adapters are unsupported
by this release.

#### Verified functionality on BE201 / Sequoia

- Native macOS Wi-Fi interface and network scanning.
- Open-network and WPA2-Personal (PSK/CCMP) connections with DHCP.
- User-initiated switching between networks.

### 首次发布

AirportBZ 的首个公开版本，以 `AirportItlwm.kext` 形式提供实验性的 macOS 原生 Wi-Fi
驱动。可直接通过系统 Wi-Fi 菜单扫描和连接网络，无需 HeliPort。

#### 平台支持

| macOS / 架构 | 网卡 | 当前状态 |
| --- | --- | --- |
| Sequoia 15.2+（`Darwin 24.2.0–24.99.99`），x86_64 | Intel BE201（`8086:7740`） | 主要支持平台，已通过真机验证。 |
| Sequoia 15.2+（`Darwin 24.2.0–24.99.99`），x86_64 | Intel BE200（`8086:272B`） | 已包含设备适配和固件，仅通过编译检查。要求 GL-C0 / FM-C0 步进。 |
| Tahoe 26，x86_64 | Intel BE201 / BE200 | 提供独立构建目标，仅通过编译检查，尚未进行真机验证。 |

目前只有 BE201 搭配 Sequoia 经过真机验证，BE200 和 Tahoe 的实际运行兼容性尚未验证。
请使用与 macOS 版本对应的驱动包。本版本不支持更早的 macOS 或其他 Intel 无线网卡。

#### BE201 / Sequoia 已验证功能

- 系统原生 Wi-Fi 界面与网络扫描。
- 开放网络及 WPA2-Personal（PSK/CCMP）连接与 DHCP。
- 用户主动切换网络。

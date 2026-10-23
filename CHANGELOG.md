# Changelog

All notable changes to the AirportBZ project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## 📌 Release Specification & How to Version / 版本发布规范说明

> **CI 发布机制说明**：
> 1. **版本号决定权**：GitHub Actions CI 在发布时，会自动读取本文档中**最上方第一个 `## [vX.Y.Z]`** 标题作为当前发布的 Release Tag（例如 `v2.4.0`）。
> 2. **更新说明提取**：CI 会自动截取该版本号与下一个版本号之间的 Markdown 文本，作为 GitHub Release 页面的更新说明（Release Notes）。
> 3. **如何发布下一个版本**：
>    - 当您准备发布新版时，只需在本文档顶部添加一个新的版本块，例如：
>      ```markdown
>      ## [v2.4.1] - 2026-11-01
>
>      ### Fixed
>      - 修复了某某问题...
>      ```
>    - 推送（`git push`）到 `main` 分支后，CI 便会**自动以 `v2.4.1` 为名编译 Release 并创建 Release 发布**！
> 4. **分类标签规范**：
>    - `Added`：新功能、新支持的硬件或系统。
>    - `Changed`：已有功能的调整、重构或性能优化。
>    - `Fixed`：缺陷、断言（Assert）或兼容性崩溃修复。
>    - `Removed`：被删除、废弃的代码或旧特性。

---

## [v2.4.0] - 2026-10-23

### Added
- **Intel Wi-Fi 7 BE201 原生支持**：为 Intel Wi-Fi 7 BE201（`8086:7740`，CNVio3 接口，包含 Killer BE1750i）在 macOS Sequoia 15.2+ 上提供原生 AirPort / Skywalk 驱动支持。
- **Intel Wi-Fi 7 BE200 架构就绪**：完成 Intel Wi-Fi 7 BE200（`8086:272B`，PCIe 独立网卡）驱动与 `gl-c0-fm-c0-92` 专有固件适配，支持 GL MAC（`0x47`）及 C0 步进硬件。
- **专有 DMA 内存架构**：为 BZ/GL 家族网卡配置 64 MiB 专用 DMA 内存池，并严格限制单次分配不跨越 4 GiB 硬件物理边界。
- **高性能 MSI-X 中断**：在初始化早期请求配置 MSI-X 消息中断，解决传统中断无法锁存 RX 接收完成的问题。
- **原生系统特性联动**：菜单栏原生 Wi-Fi 控制中心直接可用、网络即时扫描、iPhone 个人热点快速连入、CoreLocation Wi-Fi 辅助定位完全正常。

### Changed
- **驱动彻底纯净化瘦身**：全面清理并物理移除了 37,876 行 Wi-Fi 4/5 历史老网卡代码（`hal_iwm` 与 `hal_iwn`），删除数百兆过时固件。
- **编译单元高度精简**：参与 Sequoia 构建的源文件由原先的 74 个大幅精简为 57 个，提升编译速度。
- **二进制体积优化**：最终内核扩展二进制体积缩减至 2.25 MB（瘦身约 250 KB 死代码）。
- **信号宏原生收敛**：移除对老旧 `IWM_MIN_DBM` 宏的间接依赖，原生收敛至 `IWX_MIN_DBM`（-100 dBm）。
- **BE200 离散参数对齐**：参考 Linux 7.0 离散网卡规范移除多余的 2500 微秒 LTR 延迟。

### Fixed
- **解决 WPA2 握手超时 `-3905`**：在 net80211 协议栈中引入 EAPOL 帧暂存机制，解决 AP 提前发送 Message 1 与驱动底层 MLD 初始化耗时的竞态，实现 50~160ms 极速连网。
- **消除固件断言崩溃**：严格规范断开网络时的硬件解构时序（BAID 块确认 $\to$ 密钥 Key $\to$ 发送队列 TX Queue $\to$ 站点 STA），彻底消除 UMAC `0x20000072` / `0x20101e08` 崩溃断言。
- **修复 CI 脚本执行权限**：修复 GitHub Actions 环境下 `scripts/fw_gen.sh` 缺少可执行权限导致的 `Permission denied` 编译失败问题。

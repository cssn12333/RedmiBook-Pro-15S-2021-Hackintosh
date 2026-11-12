# v1.0.3 核显与 QQ 启动更新

2026-11-12，维护者确认使用提供的 weachy NootedRed v1.2.4 测试 EFI 后，最新版 QQ 无法启动的问题已解决。本版本据此更新公开 EFI，系统基线为 macOS15.7.5 / 24G624，处理器为 Ryzen5600H Cezanne。

## 当前配置

| 项目 | 配置 |
|---|---|
| 核显插件 | weachy/NootedRed v1.2.4 RELEASE |
| 先前插件 | ChefKissInc/NootedRed v0.8.10 |
| GLFix | 采用1.2.4默认开启状态 |
| VDA硬件视频加速 | 采用1.2.4默认开启状态 |
| 启动参数 | `-btlfxboardid`，保留蓝牙USB传输识别修复 |
| 加载顺序 | Lilu1.7.2 → NootedRed1.2.4 → AppleALC1.9.8 |
| AMFIPass及SIP | 沿用实测EFI，SIP为01000000，满足现有系统内麦克风驱动配置 |

更新范围为NootedRed的Info.plist、可执行文件及config中的版本注释。现有Wi-Fi共存内存补丁、蓝牙固件、USB映射、ACPI、CPU补丁与机器模型继续使用实测配置。

## GL 与 VDA 分别处理什么

GLFix处理应用的图形渲染路径，涉及OpenGL与Metal中的混合绘制和界面合成。Electron类应用启动、窗口和菜单渲染可以触发相关问题。QQ原先打不开，采用本次组合后用户确认恢复。此前未提供QQ崩溃栈，具体触发函数仍未定位。

VDA在这个分支中表示通过VideoToolbox连接AMD VCN的视频加速路径，覆盖上游声明的AVC/H.264与HEVC/H.265功能。驱动默认启用VDA可以说明配置状态，实际格式支持和是否选中硬件会话需要分别检测。

本次按用户要求同时启用GLFix与VDA。用户反馈为当前问题已解决，H.264、HEVC8-bit、HEVC10-bit、视频编码以及更新后的反复睡眠测试结果尚未逐项回报。v1.0.2的蓝牙睡眠测试记录保留在 [蓝牙睡眠修复](BLUETOOTH-SLEEP.md)。

## 文件来源与校验

发布插件逐字节来自weachy官方发行资产，内容与维护者测试包一致。

- [v1.2.4发行页](https://github.com/weachy/NootedRed/releases/tag/v1.2.4)
- 发行资产 `NootedRed-1.2.4-RELEASE.zip` 的SHA256为 `68167fdca0558b90281fe3f521abd4d477127593d8930f4a2ea4ebccc8ec40ad`
- 插件可执行文件SHA256为 `708926aa3f3b43454acd2a1cae1f7214ce6b3416335a39448e0591fa597caa04`
- 对应完整源码保存在 `Sources/Upstream/weachy--NootedRed-v1.2.4.tar.gz`，许可原文位于 `Licenses/weachy--NootedRed--LICENSE.md`

公开包继续使用GoldenGate主题，并清空MLB、序列号、UUID与ROM。原始测试日志与私人EFI保存在维护者本地。

# v1.0.2：蓝牙睡眠恢复与 USB 传输识别

适用本项目已经验证的组合：Ryzen 5600H / RTL8852AE、蓝牙 USB 0CB8:C549、MacBookPro16,3、macOS 15.7.5 (24G624)、BlueToolFixup 2.7.2。其他机型和驱动版本应先检查自己的日志。

## 问题与最终改动

蓝牙开机能正常工作，睡眠唤醒后可能自动关闭、无法打开或搜索不到设备，同时 Wi-Fi 无法重新连接。重启整机可以恢复。早期 USBX 和内部端口修正曾通过短时测试，后续仍能复现，不能把早期结果当作永久修复。

v1.0.2 的唯一启动配置变化是增加：

```text
NVRAM → Add → 7C436110-AB2A-4BBB-A880-FE41995C9F82 → boot-args
-btlfxboardid
```

原有 `NVRAM → Delete` 已包含 `boot-args`；原有三个蓝牙 NVRAM 变量、固件加载器、USB 映射、USBX 和 Wi-Fi 共存补丁均保留。没有替换驱动二进制、修改 SMBIOS 身份、关闭系统睡眠或安装常驻恢复服务。

使用者如果已有其他必要的启动参数，应在原参数后追加，不能为了加入这一项清空自己的参数。

## 证据与判断

| 阶段 | 本机脱敏观察 | 能得出的结论 |
|---|---|---|
| 睡眠唤醒 | 两个 USB 控制器记录 lost power，蓝牙被移除后重新枚举 | 需要检查恢复路径；不是只看开关 |
| 第一次故障快照 | USB 蓝牙仍存在，但没有 FirmwareLoaded 标记或挂接的固件加载器实例 | 标记缺失不等于已证实固件丢失，也可能是已加载固件后重新匹配失败 |
| 临时恢复测试 | Wi-Fi off/on 成功，Wi-Fi 恢复；重启 bluetoothd 后蓝牙仍故障 | 单独重启服务不足以解决这次蓝牙问题 |
| 服务重新初始化 | 蓝牙显示地址 NULL、Off、BCM_4350C2、版本 v0、传输 PCIe；真实设备却是 USB | 系统选择的蓝牙传输路径与硬件不符 |
| 初始化错误 | 等待不存在的 AppleConvergedIPCControl 90 秒，随后 StackManager::initTransport 失败 | 优先纠正 USB/PCIe 机型识别路径 |
| 加入参数后 | 实际启动参数包含 -btlfxboardid；睡前与醒后均为 USB / THIRD_PARTY_DONGLE / On，保留有效地址和固件版本，醒后 Enco X3 连接 | 本轮修正后的睡眠唤醒测试通过 |
| 同轮 Wi-Fi | 睡前与醒后接口均 active，并保留相同 IP；用户确认正常 | 本轮 Wi-Fi 恢复也正常；不据此宣称该蓝牙参数单独修复了所有 Wi-Fi 电源问题 |

最后一次成功测试没有执行临时 Wi-Fi 开关或蓝牙服务重启，不能把恢复归功于采集脚本。

## 为什么是这个参数

[官方 BlueToolFixup 2.7.2 源码](https://github.com/acidanthera/BrcmPatchRAM/blob/2.7.2/BrcmPatchRAM/BlueToolFixup.cpp) 中，Sonoma 及之后仅在检测到 `-btlfxboardid` 时启用 board-id 表修正。它在 BlueTool 和 bluetoothd 中，把 USB 蓝牙机型表里的一个 board-id 替换为当前机器的 board-id，让当前机型也能进入 USB 传输路径。

本项目使用 MacBookPro16,3，而该笔记本的真实蓝牙通过内部 USB 连接。源码行为、PCIe/ACIPC 失败日志以及加参后的 USB 实测结果共同支持这个修复方向。补丁没有把 Realtek 芯片变成 Broadcom，也没有重新烧写网卡固件。

`-btlfxnvramcheck` 在这份官方源码中只用于 Sonoma 及以前，因此没有为 Sequoia 盲目添加。也没有添加缺乏本机日志依据的地址检查绕过参数或 Intel/Broadcom 固件驱动。

## 与现有共存补丁的区别

- [Wi-Fi/蓝牙共存补丁](COEXISTENCE.md)：针对指定 AirportRTW 二进制跳过强制 Wi-Fi-only 初始化策略，解决本机连接 Wi-Fi 时蓝牙失效的早期问题。
- [USB 映射与 USBX](USB-MAP.md)：确认内部蓝牙端口与提供 USB 逻辑电源属性。
- 本轮 `-btlfxboardid`：修正蓝牙服务重新初始化时选择的传输路径。

三个部分解决的层次不同，不能互相替代。USB 控制器在睡眠中重置的底层原因没有通过这次参数修改单独定位，也没有为了掩盖故障禁止睡眠。

## 诊断工具

仓库提供 `Tools/Bluetooth-Sleep-Diagnostics.command`。可在目标 macOS 双击运行，或执行：

```bash
bash Tools/Bluetooth-Sleep-Diagnostics.command
```

选择 1 记录睡眠前后，选择 2 表示故障已经发生。工具会提示请求管理员权限，保存蓝牙、USB、Wi-Fi、启动参数、进程与系统日志；明确报告故障时才尝试临时关闭原本开启的 Wi-Fi、重启 bluetoothd，再恢复 Wi-Fi。该步骤会短暂断网，不修改 EFI、不删除配对或已保存 Wi-Fi，也不安装后台服务。

日志位于项目根目录 `Diagnostics/BT-Sleep-日期时间`，该目录已加入 `.gitignore`。日志可能包含设备地址、网络与机器信息，不能直接作为公开发行包提交。工具语法和输入分支检查通过；具体恢复顺序曾实机运行，结果是 Wi-Fi 恢复、蓝牙未恢复，最终修复来自 EFI 参数，而不是这个临时恢复功能。

## 验证范围

2026-11-04，本机用户确认修正后的睡眠唤醒、Wi-Fi 和 Enco X3 连接正常，对照日志也符合。此版本未覆盖任意时长、任意次数的睡眠或长时休眠。未增加传感器测试插件；CPU/GPU 功耗与电池读数研究仍不属于这次稳定发行。

原始日志、设备地址、私有 EFI 身份和本机排障备份不在仓库中。

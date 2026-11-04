# RedmiBook Pro 15S 2021 · Ryzen 5 5600H · macOS 15.7.5

面向 RedmiBook Pro 15S 2021 / XMA2007-BJ 的 OpenCore EFI、配置说明与排障工程。CPU 为 **Ryzen 5 5600H，6核12线程**，网卡为 **Realtek RTL8852AE**。本项目记录在一台实机上从安装、网卡死机排障到蓝牙共存、USB睡眠电源和麦克风输入的过程，供同硬件用户参考。

**这不是通用EFI，也不是所有功能均受支持的“完美驱动”。** 已验证系统为 macOS Sequoia **15.7.5 / 24G624**。未验证 macOS26。5800H、5500U、Intel版和其他网卡不能直接照搬。

## 硬件与状态

| 项目 | 本机配置 / 验证结果 |
|---|---|
| CPU | Ryzen 5 5600H；AMD补丁按6个物理核心配置 |
| 核显 | Vega / NootedRed0.8.10，用户确认正常进入桌面和使用 |
| 声卡 | Realtek ALC256 / AppleALC1.9.8 / layout67；内置扬声器正常 |
| 存储 | 512GB BG40；NVMeFix启用 |
| Wi-Fi | RTL8852AE / AirportRTW2.3.0 Sequoia原生前端；已连接上网 |
| 蓝牙 | USB 0CB8:C549 / RealtekBluetoothFirmware1.0.2 + BlueToolFixup2.7.2；Enco X3与Wi-Fi共存通过一次联合测试 |
| 手机共享 | 小米手机USB网络共享 / HoRNDIS-Host9.4 |
| 内置麦克风 | AMD ACP 1022:15E2 revision01；系统内安装AMDMicrophone1.0.0d1后，用户确认输入音量条响应 |
| 合盖 / 唤醒 | 最新一次联合测试正常，唤醒后蓝牙和麦克风仍识别 |
| U盘热拔 | 最新一次测试，耳机无中断 |
| AirPlay | 红米发送到桌面及两端同步发声正常；**桌面将红米加入接收组后两端静音，取消红米后桌面恢复；未解决** |
| 其他 | HDMI音频、DRM、隔空投送、全部USB插口、长时休眠、全部刷新率未逐项验证 |

测试范围与脱敏记录见 [Docs/validation.json](Docs/validation.json)，驱动版本见 [Docs/components.json](Docs/components.json)。原始日志、序列号、UUID、ROM、Wi-Fi密码及个人设备地址没有上传。

## 使用前必须做

1. 备份自己的EFI与数据，使用独立U盘测试。本项目不包含macOS镜像，也不需要格式化系统硬盘。
2. 核对硬件，尤其是CPU物理核心数、网卡和蓝牙USB编号。
3. 用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 为自己的机器生成 MacBookPro16,3 的身份数据，再填写 `EFI/OC/config.plist → PlatformInfo → Generic` 的 SystemSerialNumber、MLB、SystemUUID、ROM。本仓库这些字段为空或全零，**不能复制维护者的身份**。
4. 可用 `python Tools/Set-SMBIOS.py EFI/OC/config.plist` 交互填入身份，随后运行 `python Tools/Validate-EFI.py EFI` 校验。身份填写后不要把私人EFI提交到公开仓库。
5. 将 `EFI` 文件夹复制到自己的FAT32引导分区或测试U盘，先从U盘启动。

## 关键修正

- 保留与已测试配置相同的OpenCore1.0.8及全部启用驱动，未为发布盲目升级。保留原DEBUG二进制，关闭文件日志、启动刷字和OpenShell工具，清除禁用的旧驱动及ACPI文件。
- AMD内核补丁为6核；针对本机MAT情况保留现有内存映射设置，详见config，不能把它当作所有AMD电脑的通用设置。
- Wi-Fi使用Sequoia原生AirportRTW，不再加载旧IOSkywalk/IO80211Legacy和AirPort_RTW89组合。
- AirportRTW2.3.0原版初始化强制调用 `rtw88_force_wifi_only()`。本机需要蓝牙共存，所以用精确限定的OpenCore内存补丁跳过该函数，让底层保留正常共存模式。驱动磁盘文件保持官方原版。详情见 [Docs/COEXISTENCE.md](Docs/COEXISTENCE.md)。**升级Wi-Fi驱动前必须重新审查，不能沿用该补丁。**
- 原生AppleUSBXHCIPCI + USBToolBox；蓝牙XHC0/P004、摄像头XHC0/P003、指纹XHC1/P003标为内部255。指纹端口标记不等于macOS指纹认证可用。
- 添加标准SSDT-USBX。测试中USB睡眠电流属性从0变为2100，之后的合盖、唤醒与拔盘联合测试通过。USBX提供系统电源属性，不保证每块主板的物理供电策略。

## 内置麦克风需要系统内安装

`Drivers/AMDMicrophone.kext` 是上游v1.0.0发布包的Release版本，**不放进OpenCore的Kernel/Add**。上游依赖IOAudioFamily，要求安装到`/Library/Extensions`。本EFI使用`csr-active-config=01000000`，只允许未签名内核扩展这一项；不要为此关闭全部安全保护。

用此EFI启动后，运行：

```bash
sudo bash "/path/to/project/Tools/Install-Microphone.command"
```

将路径换成实际项目路径。按照系统“隐私与安全性”提示允许驱动，保存工作并重启。到声音输入选择 **AMD Digital Microphone**，用输入音量条和实际录音验证。“线路输入”不等于内置麦克风已工作。

维护者初期脚本曾使用`kmutil install --update-all`，因缺少24G624的KDK返回71；随后通过系统允许和重启，驱动已实际加载。公开安装工具改为请求加载单个驱动，不强制重建全部内核集合，也不要求为此下载KDK。公开工具的这项改动做了语法检查，尚未在干净系统上重复安装测试。

卸载脚本为`Tools/Uninstall-Microphone.command`，会把驱动移到本机备份目录而不是直接删除。切换EFI不会自动卸载系统内驱动。

## 主题与发布差异

本机U盘保留用户提供的ModernView主题；因该压缩包未附明确再分发说明，公开包使用 [OcBinaryData](https://github.com/acidanthera/OcBinaryData) 的GoldenGate主题。两份EFI的核心驱动、USB映射和补丁一致；公开版清空身份且主题不同。

## 排障与维护

- `Tools/Test-Bluetooth-Microphone.command`：分阶段验证共存、麦克风、睡眠和拔盘，日志先写本机`/Users/Shared`。
- `Tools/Bluetooth-Failure-Logs.command`：蓝牙卡住时采集USB、蓝牙、音频与近期日志。
- `Tools/交接与维护.command --airplay`：在接收端红米采集AirPlay及coreaudiod日志。
- `sudo bash Tools/交接与维护.command --cleanup`：只清理本项目的测试日志和临时采集脚本，保留正在使用的驱动及含驱动备份的目录。
- 固件和驱动升级后需重新验证；正常Wi-Fi和蓝牙不等于AirDrop/AWDL/AirPlay已完整受支持。

## 致谢与许可

基础ACPI与机型配置参考 [akwangl/RedmiBook-Pro-15S-hackintosh](https://github.com/akwangl/RedmiBook-Pro-15S-hackintosh)。感谢AMD-OSX、acidanthera、ChefKissInc、OpenIntelWireless、USBToolBox、VoodooI2C及各驱动作者。

新增文档和辅助脚本按仓库LICENSE发布；第三方EFI组件、固件、ACPI原作及源码补丁遵循各自上游许可，不因本仓库而改变。见 [THIRD_PARTY.md](THIRD_PARTY.md) 与`Licenses/`。

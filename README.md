# RedmiBook Pro 15S 2021 · Ryzen 5 5600H · macOS 15.7.5

面向 RedmiBook Pro 15S 2021 / XMA2007-BJ 的 OpenCore EFI、配置说明与排障工程。CPU 为 **Ryzen 5 5600H，6核12线程**，网卡为 **Realtek RTL8852AE**。本项目记录在一台实机上从安装、网卡死机排障到蓝牙共存、USB睡眠电源和麦克风输入的过程，供同硬件用户参考。

**当前版本：v1.0.3 · 更新日期：2026-11-12。** [下载发布包](https://github.com/cssn12333/RedmiBook-Pro-15S-2021-Hackintosh/releases/latest)。本次采用用户测试的 **weachy NootedRed v1.2.4 RELEASE**，用户确认最新版QQ无法启动的问题已解决。GLFix与VDA采用该版默认开启配置，保留v1.0.2蓝牙睡眠修复。详见 [核显与QQ更新](Docs/GRAPHICS-QQ-VDA.md)。

**这不是通用EFI，也不是所有功能均受支持的“完美驱动”。** 已验证系统为 macOS Sequoia **15.7.5 / 24G624**。未验证 macOS26。5800H、5500U、Intel版和其他网卡不能直接照搬。

## 硬件与状态

| 项目 | 本机配置 / 验证结果 |
|---|---|
| CPU | Ryzen 5 5600H；AMD补丁按6个物理核心配置 |
| 核显 | Vega / weachy NootedRed1.2.4，GLFix与VDA默认开启；用户确认QQ启动问题已解决，视频编解码格式待逐项验证 |
| 声卡 | Realtek ALC256 / AppleALC1.9.8 / layout67；内置扬声器正常 |
| 存储 | 512GB BG40；NVMeFix启用 |
| Wi-Fi | RTL8852AE / AirportRTW2.3.0 Sequoia原生前端；已连接上网 |
| 蓝牙 | USB 0CB8:C549 / RealtekBluetoothFirmware1.0.2 + BlueToolFixup2.7.2；保留共存补丁，增加USB传输机型识别；最新睡眠唤醒测试中Enco X3连接正常 |
| 手机共享 | 小米手机USB网络共享 / HoRNDIS-Host9.4 |
| 内置麦克风 | AMD ACP 1022:15E2 revision01；系统内安装AMDMicrophone1.0.0d1后，用户确认输入音量条响应 |
| 合盖 / 唤醒 | 早期USBX修正后仍曾复发；v1.0.2增加USB蓝牙机型识别后，本轮睡眠唤醒、蓝牙耳机和Wi-Fi正常；长时休眠未验证 |
| U盘热拔 | 最新一次测试，耳机无中断 |
| AirPlay隔空音频 | 手机及M4 Pro对照测试后，用户将后续9061问题定位到台式机发送端；红米接收端曾成功播放，完整双向/多扬声器稳定性仍待发送端排查 |
| 其他 | HDMI音频、DRM、隔空投送、全部USB插口、长时休眠、全部刷新率未逐项验证 |

测试范围与脱敏记录见 [Docs/validation.json](Docs/validation.json)，驱动版本见 [Docs/components.json](Docs/components.json)。原始日志、序列号、UUID、ROM、Wi-Fi密码及个人设备地址没有上传。

AirPlay曾双向正常，随后台式机向红米发送又出现9061。用户补充手机和MacBook Pro M4 Pro的对照测试，并将故障定位到台式机发送端，发送端排查待继续。红米v1.0.3采用的核显更新用于QQ启动问题，AirPlay的重新验证状态见本节。文件AirDrop仍未验证。

## 工程目录

```text
EFI/                 精简后的公开EFI，身份字段已清空
  BOOT/              UEFI默认入口
  OC/                OpenCore、config、ACPI、驱动和主题资源
Drivers/             需在macOS系统内安装的AMDMicrophone
Tools/               身份填写、完整性校验、安装/卸载和采集工具
Docs/                配置解释、验证记录、版本与来源清单
Sources/Coexistence/ Wi-Fi/蓝牙共存补丁片段和等效源码改动
Sources/USBMap/      本机USB映射的Info.plist
Sources/ACPI/        USBX电源表
Sources/Upstream/    对应版本的相关上游源码归档
Licenses/            可取得的上游许可原文
SHA256SUMS.txt       公开工程文件校验清单
```

## 配置索引

| 内容 | 说明 |
|---|---|
| OpenCore与启动参数 | [配置详解](Docs/CONFIGURATION.md) |
| Wi-Fi/蓝牙共存 | [补丁实现与验证](Docs/COEXISTENCE.md) |
| 核显、QQ与视频硬解 | [weachy 1.2.4更新与实测范围](Docs/GRAPHICS-QQ-VDA.md) |
| 蓝牙睡眠恢复 | [USB/PCIe传输识别、故障证据与v1.0.2改动](Docs/BLUETOOTH-SLEEP.md) |
| USB内部端口和电源 | [USB映射](Docs/USB-MAP.md) |
| 麦克风系统安装 | 见下文，以及`Tools/Install-Microphone.command` |
| 全部启用驱动版本 | [组件清单](Docs/components.json) |
| 实测范围 | [验证记录](Docs/validation.json) |
| 上游源码和许可 | [第三方来源](THIRD_PARTY.md)、[源码归档校验](Docs/source-archives.json) |

## 使用前必须做

1. 备份自己的EFI与数据，使用独立U盘测试。本项目不包含macOS镜像，也不需要格式化系统硬盘。
2. 核对硬件，尤其是CPU物理核心数、网卡和蓝牙USB编号。
3. 用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 为自己的机器生成 MacBookPro16,3 的身份数据，再填写 `EFI/OC/config.plist → PlatformInfo → Generic` 的 SystemSerialNumber、MLB、SystemUUID、ROM。本仓库这些字段为空或全零，**不能复制维护者的身份**。
4. 可用 `python Tools/Set-SMBIOS.py EFI/OC/config.plist` 交互填入身份，随后运行 `python Tools/Validate-EFI.py EFI` 校验。身份填写后不要把私人EFI提交到公开仓库。
5. 将 `EFI` 文件夹复制到自己的FAT32引导分区或测试U盘，先从U盘启动。

## 关键修正

- OpenCore1.0.8沿用已测试配置。v1.0.3将NootedRed由0.8.10换为用户已测试的weachy1.2.4 RELEASE，GLFix和VDA默认开启。保留原DEBUG二进制，关闭文件日志、启动刷字和OpenShell工具，清除禁用的旧驱动及ACPI文件。
- AMD内核补丁为6核；针对本机MAT情况保留现有内存映射设置，详见config，不能把它当作所有AMD电脑的通用设置。
- Wi-Fi使用Sequoia原生AirportRTW，不再加载旧IOSkywalk/IO80211Legacy和AirPort_RTW89组合。
- AirportRTW2.3.0原版初始化强制调用 `rtw88_force_wifi_only()`。本机需要蓝牙共存，所以用精确限定的OpenCore内存补丁跳过该函数，让底层保留正常共存模式。驱动磁盘文件保持官方原版。详情见 [Docs/COEXISTENCE.md](Docs/COEXISTENCE.md)。**升级Wi-Fi驱动前必须重新审查，不能沿用该补丁。**
- 原生AppleUSBXHCIPCI + USBToolBox；蓝牙XHC0/P004、摄像头XHC0/P003、指纹XHC1/P003标为内部255。指纹端口标记不等于macOS指纹认证可用。
- 添加标准SSDT-USBX。测试中USB睡眠电流属性从0变为2100，之后的合盖、唤醒与拔盘联合测试曾通过，但后续仍有复发；USBX提供系统电源属性，不保证每块主板的物理供电策略。
- v1.0.2增加 `-btlfxboardid`：启用官方BlueToolFixup2.7.2的board-id表修正，让当前MacBookPro16,3机型进入USB蓝牙路径。此前故障日志显示bluetoothd等待不存在的AppleConvergedIPCControl并循环失败；加参后最新睡眠唤醒测试中USB蓝牙、Enco X3与Wi-Fi正常。该参数与共存补丁作用不同，详见 [修复记录](Docs/BLUETOOTH-SLEEP.md)。

### 网络驱动组合

| 功能 | 实际使用的组件 | 配置作用 |
|---|---|---|
| Wi-Fi | Lilu1.7.2 → AMFIPass1.4.1 → AirportRTW2.3.0 Sequoia | 使用macOS15原生Wi-Fi界面，不依赖旧版IO80211根补丁组合 |
| 蓝牙 | BlueToolFixup2.7.2 + RealtekBluetoothFirmware1.0.2 + `-btlfxboardid` | Realtek固件上传，并修正当前机型的USB蓝牙传输路径 |
| USB网络 | HoRNDIS-Host9.4 | 小米Android手机的USB网络共享 |
| USB控制器 | AppleUSBXHCIPCI + USBToolBox1.2.0 + 本机映射 | 原生USB控制器配合已确认的内部端口 |

蓝牙选择相关NVRAM变量：`bluetoothExternalDongleFailed`为单字节00，`bluetoothInternalControllerInfo`为14字节00，`bluetoothHostControllerSwitchBehavior`为`always`。同时在Delete中列出对应键，避免旧值影响启动。具体值以仓库config为准。

### 从现象到配置的排查记录

| 阶段 | 观察到的现象 | 最终采用的处理 |
|---|---|---|
| 安装与桌面 | 完成系统安装，核显和声音逐步启用 | NootedRed + AppleALC，保留正常工作的AMD启动配置 |
| 最新版QQ | 原NootedRed0.8.10配置下无法打开 | v1.0.3换为weachy NootedRed1.2.4，用户确认问题解决；GLFix和VDA一起启用 |
| 旧Wi-Fi组合 | 输入密码连接时整机卡死 | 换为AirportRTW2.3.0原生Sequoia前端 |
| USB共享 | 小米开启共享后没有新网络接口 | 原生USB控制器与HoRNDIS-Host9.4 |
| 蓝牙识别 | 能开开关但没有设备，控制器识别不完整 | Realtek固件、BlueToolFixup和蓝牙选择变量 |
| 无线共存 | Wi-Fi连接后Enco X3断开，关闭Wi-Fi可恢复 | 针对指定二进制跳过强制Wi-Fi-only策略 |
| 睡眠后蓝牙 | USBX与内部端口修正后曾通过短时测试，后续复发；蓝牙服务重启仍误走PCIe路径 | v1.0.2增加 `-btlfxboardid`，最新睡眠唤醒后USB蓝牙、Enco X3及Wi-Fi正常 |
| 内置麦克风 | 只有线路输入，ACP没有功能驱动 | 系统内安装AMDMicrophone，实测输入音量条响应 |
| AirPlay | 曾有单向接收/多输出异常，后续双向正常 | 保留当前EFI，记录用户最新确认结果；未额外添加AirPlay补丁 |

以上是同一台机器的关联观察，不是对每一项改动做完整控制变量实验。保留这些过程，是为了说明最终组合的来源和验证边界。

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
- `Tools/Bluetooth-Sleep-Diagnostics.command`：双击选择睡前/醒后对照或当前故障；记录后可尝试临时恢复无线功能。说明见 [蓝牙睡眠修复](Docs/BLUETOOTH-SLEEP.md)，日志不上传公开仓库。
- `Tools/交接与维护.command --airplay`：在接收端红米采集AirPlay及coreaudiod日志。
- `sudo bash Tools/交接与维护.command --cleanup`：只清理本项目的测试日志和临时采集脚本，保留正在使用的驱动及含驱动备份的目录。
- 固件和驱动升级后需重新验证；正常Wi-Fi和蓝牙不等于AirDrop/AWDL/AirPlay已完整受支持。

### AirPlay两种选择入口

“控制中心→声音”用于选择当前音频输出，选中远端后本机停止播放通常符合该入口行为。“音乐”App里的AirPlay菜单可以选择多个兼容扬声器。对比两台机器能否同时发声时，应使用相同的入口、应用和播放源，而不是仅比较本机是否停声。

红米接收端在手机及M4 Pro对照测试中可用。台式机发送端后续出现9061，仍需进一步排查，文件AirDrop、随航和通用控制待验证。

## v1.0.3发布验证

- 发布包核显驱动与用户测试包的weachy1.2.4二进制逐字节一致。
- 用户于2026-11-12确认当前问题已解决。硬解启用状态来自驱动默认配置，H.264/HEVC各格式实际使用的硬解会话尚待逐项确认。
- 核显来源、上游完整源码归档、许可原文和校验清单已更新。

### v1.0.2历史发布验证

- 配置通过OpenCore1.0.8对应的ocvalidate校验。
- 检查所有启用ACPI、UEFI驱动、kext路径及关键加载顺序。
- 核对AirportRTW官方二进制哈希与共存补丁的版本绑定。
- 核对本机U盘EFI与私人最终备份的736个文件；公开包身份字段单独清空，主题改为GoldenGate。
- GitHub仓库与发布包均不包含个人原始日志；SHA256SUMS记录各公开文件，发布页给出压缩包哈希。
- v1.0.2相对v1.0.1的EFI变化仅为启动参数增加 `-btlfxboardid`；原驱动、共存补丁与USB配置不变。
- 本次对照日志确认实际参数生效，睡前与醒后蓝牙均为USB且正常，醒后Enco X3已连接，Wi-Fi接口保持active。成功测试没有触发临时恢复步骤。
- 新增传输识别说明与独立诊断工具；工具有读取超时和日志大小限制，公开包未加入尚未实测的CPU/GPU传感器插件。

## 致谢与许可

基础ACPI与机型配置参考 [akwangl/RedmiBook-Pro-15S-hackintosh](https://github.com/akwangl/RedmiBook-Pro-15S-hackintosh)。感谢AMD-OSX、acidanthera、ChefKissInc、weachy、OpenIntelWireless、USBToolBox、VoodooI2C及各驱动作者。

新增文档和辅助脚本按仓库LICENSE发布；第三方EFI组件、固件、ACPI原作及源码补丁遵循各自上游许可，不因本仓库而改变。见 [THIRD_PARTY.md](THIRD_PARTY.md) 与`Licenses/`。

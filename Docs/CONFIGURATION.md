# 配置详解

本文对应v1.0.3实际config。5600H/RTL8852AE本机采用weachy NootedRed1.2.4 RELEASE，保留v1.0.2的 `-btlfxboardid` USB蓝牙机型识别。核显更新与QQ验证详见 [GRAPHICS-QQ-VDA.md](GRAPHICS-QQ-VDA.md)。

## OpenCore与系统标识

OpenCore1.0.8，保留与正常测试时相同的DEBUG二进制；`Misc/Debug/Target=0`，关闭AppleDebug、ApplePanic与SysReport，启动参数中去掉`-v`、`keepsyms=1`、`debug=0x100`。这属于发布时的日志与显示整理，不改变核显、音频、USB或Wi-Fi驱动。

当前启动参数为 `-btlfxboardid`。官方BlueToolFixup2.7.2在Sonoma及以后需要该参数才启用board-id表修正；本机睡眠恢复与服务重启时曾误走PCIe蓝牙路径，加参后最新对照测试通过。原NVRAM/Delete已包含boot-args。详见 [蓝牙睡眠修复](BLUETOOTH-SLEEP.md)。

SMBIOS使用MacBookPro16,3。公开config中的SystemSerialNumber、MLB为空，SystemUUID和ROM为零，供使用者自行填入。机器自用EFI的真实身份没有提交到仓库。

SecureBootModel为Disabled，LauncherOption为Disabled。SIP配置为`01000000`，用于上游AMDMicrophone的系统内安装方式。

## AMD内核与内存映射

采用AMD_Vanilla补丁，并按5600H的6个物理核心处理相关替换值。config共保存27项Kernel/Patch，其中24项启用；是否应用还取决于每项Darwin版本范围。最后的共存补丁独立限定在Darwin24.x和AirportRTW2.3.0。

本机MAT相关启动调整：

| Booter/Quirks | 值 |
|---|---|
| AvoidRuntimeDefrag | true |
| DevirtualiseMmio | false |
| EnableWriteUnprotector | true |
| RebuildAppleMemoryMap | false |
| SetupVirtualMap | false |
| SyncRuntimePermissions | false |
| ProvideCustomSlide | true |

这些值是本机启动排查后的结果，不是仅凭CPU型号即可套用的统一模板。Kernel/Quirks中保留ProvideCurrentCpuInfo、DisableIoMapper等当前组合；NVMe使用SetApfsTrimTimeout=0。

## 核显、声音、传感器

- weachy NootedRed1.2.4 RELEASE负责Vega核显，加载位置在Lilu之后、AppleALC之前。GLFix与VDA按该版默认开启，boot-args继续为 `-btlfxboardid`。用户确认QQ启动问题已解决，硬解格式支持待逐项实测。
- AppleALC1.9.8负责ALC256，HDEF路径为`PciRoot(0x1)/Pci(0x8,0x1)/Pci(0x0,0x6)`，layout-id67。
- AMDMicrophone1.0.0d1单独处理ACP数字麦克风，放在系统`/Library/Extensions`，不加入EFI的Kernel/Add。
- VirtualSMC1.3.8配合SMCBatteryManager、SMCLightSensor；ECEnabler处理EC读取。
- AMDRyzenCPUPowerManagement0.7.2用于AMD Power Gadget所需的CPU接口。
- ForgedInvariant1.5.0、RestrictEvents1.1.6、NVMeFix1.1.3沿用当前组合，没有修改P-State、电压或BIOS功耗参数。

## 输入设备

VoodooPS2Controller2.3.7与键盘插件用于PS/2输入；VoodooI2C2.9.1、VoodooGPIO、VoodooI2CServices、VoodooInput与VoodooI2CHID用于I2C触控板链路。BrightnessKeys1.0.3用于亮度按键。

此处说明加载组合；详细手势、所有功能键和每个外设并未完成逐项测试矩阵。

## ACPI清单

| 文件 | 在本机配置中的作用 |
|---|---|
| SSDT-BTIF | 沿用机型参考的BAT_INFO/电池字段兼容表，文件名不代表蓝牙固件驱动 |
| SSDT-LID0 | 合盖与EC事件相关适配 |
| SSDT-ALS0 | 环境光设备适配 |
| SSDT-PNLF | 内屏背光设备 |
| SSDT-PLUG-ALT | AMD平台处理器兼容适配 |
| SSDT-EC | EC设备兼容 |
| SSDT-GPRW | 沿用机型参考的唤醒方法适配 |
| SSDT-XOSI | 配合_OSI→XOSI改名 |
| SSDT-USBX | USB睡眠/唤醒电源属性 |

ACPI补丁保留参考配置中已正常使用的_OSI、HPTL、_Q80、GPRW处理，未把原始DSDT或完整固件报告发布为替换表。

## 启动界面与文件整理

OpenCanopy启用，PickerMode为External，显示选择器，超时10秒。公开包使用`Acidanthera\GoldenGate`，本机保留用户提供的ModernView。

发布EFI只保留启用的ACPI、根级kext与UEFI驱动；移除了旧网络组合、GenericUSBXHCI、UTBDefault、旧USB映射及OpenShell工具的无效引用和多余文件。启用根kext内随包携带的插件保持原样，具体加载以Kernel/Add为准。

## 文件一致性

`Tools/Validate-EFI.py`检查引用路径、关键加载顺序和共存补丁对应的AirportRTW哈希。`SHA256SUMS.txt`记录公开工程文件。该脚本不替代对应版本的ocvalidate；维护者已另外使用OpenCore1.0.8的ocvalidate完成校验。

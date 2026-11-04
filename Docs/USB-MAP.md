# USB映射与电源

当前映射为`Redmi5600HUSBPowerMap.kext`1.1.0，配合USBToolBox1.2.0和原生AppleUSBXHCIPCI。XHC0、XHC1均匹配AMD1022:1639，每个控制器保留逻辑端口1–6。

| 控制器 | 逻辑端口 | 当前UsbConnector | 已有证据 |
|---|---|---|---|
| XHC0 | P001 | 0 | 未完成物理插口确认 |
| XHC0 | P002 | 0 | 联合日志中出现外置无线接收器 |
| XHC0 | P003 | 255 | 内置XiaoMi USB2.0摄像头 |
| XHC0 | P004 | 255 | 内置Realtek蓝牙0CB8:C549 |
| XHC0 | P005 / P006 | 0 | 未完成物理插口确认 |
| XHC1 | P001 / P002 | 0 | 未完成物理插口确认 |
| XHC1 | P003 | 255 | 内置ELAN指纹模块，仅确认USB位置 |
| XHC1 | P004 | 0 | 联合日志中出现Kingston引导U盘 |
| XHC1 | P005 / P006 | 0 | 未完成物理插口确认 |

255表示内部端口。其他端口的0沿用初始映射，不能据此把所有物理接口都认定为USB2.0。此映射尚未覆盖每个USB-A/USB-C插口及正反插、USB2/USB3配对的完整实物测试。

## 为什么增加USBX

在出现蓝牙睡眠恢复问题时，日志中各端口的`kUSBSleepPortCurrentLimit`为0，未见USBX设备。增加Dortania标准USBX表后，该属性变为2100，后续一次完整联合测试中，合盖唤醒和拔盘后耳机仍保持连接，麦克风输入也仍被识别。

标准表提供以下逻辑电源属性：

| 属性 | 数值 |
|---|---|
| kUSBSleepPowerSupply | 5100 |
| kUSBSleepPortCurrentLimit | 2100 |
| kUSBWakePowerSupply | 5100 |
| kUSBWakePortCurrentLimit | 2100 |

该表告诉macOS采用的USB电源参数，不是直接改写主板电源轨或保证任何固件下都不掉电。早期测试曾通过，但后续仍出现蓝牙恢复故障；v1.0.2增加 `-btlfxboardid` 修正用户态USB/PCIe识别后，本轮睡眠唤醒通过。不能把USBX单独视为完整修复，也不等于已经验证长时休眠、所有外设或全部USB插口。见 [蓝牙睡眠恢复](BLUETOOTH-SLEEP.md)。

## 蓝牙恢复时的判断

之前的故障并非只发生在拔盘瞬间：历史日志显示第一次合盖唤醒时，蓝牙USB设备就已被移除，重新枚举后没有固件加载服务接管，随后用户态蓝牙命令失败。正常状态应同时结合USB设备树、固件加载情况、蓝牙控制器信息和耳机实际播放判断，不能只看开关是否打开。

映射源码在`Sources/USBMap/Info.plist`，USBX表在`Sources/ACPI/SSDT-USBX.aml`。

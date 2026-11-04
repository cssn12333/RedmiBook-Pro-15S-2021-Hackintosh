# RTL8852AE 的共存补丁

现用官方AirportRTW2.3.0 Sequoia的二进制SHA256：

`38b1e03fe383327aad5399ed92f7a931048ae47f4c1d67a21867ecd5b70c7060`

源码链：Rtw89LinuxBridge.cpp的attach无条件调用`rtw88_force_wifi_only()`；RTW89的Senmiko.c把标志设为true，core.c因而选用BTC_MODE_WL。这个策略面向没有可用蓝牙的系统，不适合本机已经能工作的Realtek蓝牙。

OpenCore补丁以`_rtw88_force_wifi_only`符号为Base，使用16字节入口签名和重定位掩码，Limit16、Count1，仅Darwin24.x。把入口栈帧的4字节替换成RET+NOP；跳过整个void辅助函数，标志保留BSS初值false，底层使用BTC_MODE_NORMAL。没有修改文件内的驱动，也没有改RTW88另一个同名功能的辅助函数。

静态核验：符号唯一、只有一个attach调用、getter/setter指向同一BSS标志、补丁恰好修改4字节、官方文件哈希正确、ocvalidate通过。实机OpenCore日志记录replace count1及Success；用户随后确认Wi-Fi和Enco X3共存。

睡眠后出现的另一问题来自USB蓝牙恢复路径：控制器在唤醒时被移除，重新枚举后没有固件加载标记，用户态命令失败。补充USBX和内部端口修正后，最新一次睡眠及拔盘联合测试通过。不能据此断言该内存补丁单独解决了睡眠问题。

源代码等效改动在`Sources/Coexistence/rtl8852ae-normal-coexistence.patch`，只用于解释策略，未编译成新驱动。OpenCore补丁片段也在同目录。它是针对本机和指定二进制的局部改动，不是上游通用修复。升级AirportRTW必须重新审计；AirPlay接收无声仍是已知问题。

上游：https://github.com/souissiak1-maker/AirportRTW/tree/V2.3.0

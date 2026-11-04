#!/bin/bash
# RedmiBook Pro 15S 2021 / XMA2007-BJ / Ryzen 5 5600H / RTL8852AE
# 版本：v1.0.2；macOS15.7.5(24G624)，已验证USB蓝牙机型识别与本轮睡眠恢复。
# GitHub：https://github.com/cssn12333/RedmiBook-Pro-15S-2021-Hackintosh
# 麦克风已装入 /Library/Extensions/AMDMicrophone.kext，不能清理该驱动。
# USB保留ModernView主题和本机SMBIOS；GitHub公开包清空身份并使用GoldenGate。
# 工程与备份位置由使用者自行选择；原始日志和机器身份不得提交公开仓库。
set -u
case "${1:---help}" in
  --help)
    printf '%s\n' 'v1.0.2 EFI交接说明' \
      '已验证：核显、扬声器、Wi-Fi、Enco X3蓝牙共存、小米USB共享、麦克风输入音量条、合盖唤醒及拔盘保持连接。' \
      'AirPlay：用户最新确认双向音频互传正常；此前短暂异常原因未确定，文件AirDrop仍未验证。' \
      '未保证：全部USB插口定制、HDMI音频、DRM、隔空投送、长时休眠及macOS26。' \
      '本机身份保留在EFI中，不能把本U盘EFI直接公开；请分享GitHub脱敏版本。' \
      '麦克风已安装在系统内，不在EFI里；重装系统后从GitHub下载Drivers与Tools重新安装。' \
      'GitHub: https://github.com/cssn12333/RedmiBook-Pro-15S-2021-Hackintosh' \
      '' \
      '清理本次macOS测试日志：' \
      'sudo bash "/Volumes/OCDEBUG/交接与维护.command" --cleanup' \
      '' \
      '采集AirPlay接收无声：' \
      'sudo bash "/Volumes/OCDEBUG/交接与维护.command" --airplay' \
      '' \
      '清理只处理本项目生成的日志、临时采集脚本，不卸载驱动，不删除系统音频缓存。' \
      'OpenCore文件日志与启动刷字已关闭，原驱动版本和运行时补丁保留。' \
      'v1.0.2增加 -btlfxboardid，最新睡眠唤醒后USB蓝牙、Enco X3和Wi-Fi正常。' \
      '睡眠诊断：bash Tools/Bluetooth-Sleep-Diagnostics.command；日志保留在本地。'
    exit 0 ;;
  --cleanup|--airplay) mode="$1" ;;
  *) printf '参数：--help、--cleanup 或 --airplay\n'; exit 1 ;;
esac
if [ "$(uname -s)" != Darwin ] || [ "${EUID:-$(id -u)}" -ne 0 ]; then
  printf '请在目标macOS使用 sudo bash 运行。\n' >&2
  exit 1
fi
if [ "$mode" = --cleanup ]; then
  count=0
  for dir in /Users/Shared/OC-Microphone-Install-* /Users/Shared/OC-BTMic-Test-* /Users/Shared/OC-Bluetooth-Failure-* /Users/Shared/OC-USB-Unplug-* /Users/Shared/OC-AirPlay-Logs-*; do
    [ -d "$dir" ] && [ ! -L "$dir" ] || continue
    parent="$(cd "$(dirname "$dir")" && pwd -P)"
    [ "$parent" = /Users/Shared ] || continue
    if find "$dir" -name '*.kext' -print -quit | grep -q .; then
      printf '保留含驱动备份的目录：%s\n' "$dir"
      continue
    fi
    printf '清理项目日志：%s\n' "$dir"
    rm -rf -- "$dir" || exit 1
    count=$((count+1))
  done
  for file in /private/tmp/OC-BTMic-Test.* /private/tmp/OC-USB-Unplug.*; do
    [ -f "$file" ] && [ ! -L "$file" ] || continue
    parent="$(cd "$(dirname "$file")" && pwd -P)"
    [ "$parent" = /private/tmp ] || continue
    rm -f -- "$file" || exit 1
  done
  sync
  printf '清理完成，共清理 %s 个项目日志目录；已安装驱动保留。\n' "$count"
  exit 0
fi
log_dir="/Users/Shared/OC-AirPlay-Logs-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$log_dir" || exit 1
printf '本机日志：%s\n' "$log_dir"
sw_vers > "$log_dir/system-version.txt"
kmutil showloaded > "$log_dir/loaded-kexts.txt" 2>&1
system_profiler SPAudioDataType -json > "$log_dir/audio-before.json" 2>&1
ifconfig -a > "$log_dir/interfaces.txt" 2>&1
/usr/bin/log stream --style compact --level debug --predicate 'process == "AirPlayXPCHelper" OR process == "AirPlayUIAgent" OR process == "AirPlayReceiver" OR process == "AirPlayReceiverAgent" OR process == "coreaudiod" OR process == "sharingd" OR process == "Music" OR eventMessage CONTAINS[c] "AirPlay" OR eventMessage CONTAINS[c] "RAOP" OR eventMessage CONTAINS[c] "AudioTimeSync"' > "$log_dir/live.log" 2>&1 &
pid=$!
finish() { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; sync; }
trap finish EXIT
trap 'exit 130' INT TERM
printf '\n此工具可在红米接收端和Mac Pro发送端同时运行。红米先断开耳机，选择内置扬声器。\n请在Mac Pro音乐App先只选本机播放，再加入红米等待30秒，再取消红米等待10秒。\n记录每步两台机器是否有声。最后用控制中心只选红米测试一次。完成后按回车。\n'
read -r ignored
printf '填写两种发送方式的结果：'
IFS= read -r note
printf '%s\n' "$note" > "$log_dir/observation.txt"
system_profiler SPAudioDataType -json > "$log_dir/audio-after.json" 2>&1
ioreg -l -w0 > "$log_dir/ioreg.txt" 2>&1
kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
chmod -R a+rX "$log_dir"
printf 'Saved locally: %s\n' "$log_dir"
printf '请保留此目录用于分析；--cleanup 会清理它。\n'

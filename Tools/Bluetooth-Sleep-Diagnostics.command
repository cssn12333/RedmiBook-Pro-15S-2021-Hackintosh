#!/bin/bash
# Capture sleep/wake before recovery. On a reported failure, temporarily disable
# active Wi-Fi, restart bluetoothd and restore Wi-Fi. No EFI/NVRAM/persistent edits.
set -u
PATH=/usr/bin:/bin:/usr/sbin:/sbin
MODE="${1:---bluetooth}"
case "$MODE" in
  --help)
    echo '双击本文件运行：1=睡眠前后诊断；2=已经发生蓝牙故障。'
    echo '会提示输入 macOS 登录密码，日志自动保存到项目根目录 Diagnostics，原始日志不要公开上传。'
    exit 0 ;;
  --bluetooth|--bluetooth-now) ;;
  *) echo '参数：--bluetooth、--bluetooth-now 或 --help'; exit 2 ;;
esac
if [ "$(uname -s)" != Darwin ]; then
  echo '请在目标红米 macOS 运行 Bluetooth-Sleep-Diagnostics.command。'; exit 1
fi
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo '请输入 macOS 登录密码（输入时不显示字符），用于读取完整诊断信息。'
  exec /usr/bin/sudo /bin/bash "$0" "$@"
fi
if [ "$#" -eq 0 ]; then
  echo '蓝牙睡眠诊断'
  echo '1 = 当前正常，记录睡眠前后状态（直接回车也选择此项）'
  echo '2 = 蓝牙已经卡住/关闭/搜索不到，直接记录故障并尝试恢复'
  echo 'q = 退出'
  IFS= read -r CHOICE || exit 1
  case "$CHOICE" in
    1|''|正常|睡眠) MODE=--bluetooth ;;
    2|故障|异常|卡住) MODE=--bluetooth-now ;;
    q|Q) exit 0 ;;
    *) echo '请输入 1、2 或 q 后重新运行。'; exit 2 ;;
  esac
fi
BASE="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$BASE"
if [ -f "$BASE/../EFI/OC/config.plist" ]; then
  PROJECT_ROOT="$(cd "$BASE/.." && pwd -P)"
fi
if [ ! -f "$PROJECT_ROOT/EFI/OC/config.plist" ]; then
  echo '请保留仓库目录结构，Tools 与 EFI 应位于同一个项目根目录。'; exit 1
fi
ACTIVE_BOOT_ARGS="$(sysctl -n kern.bootargs 2>/dev/null || nvram boot-args 2>/dev/null)"
case " $ACTIVE_BOOT_ARGS " in
  *" -btlfxboardid "*) echo '已检测到本轮 USB 蓝牙识别参数。' ;;
  *) echo '提示：当前启动未检测到 -btlfxboardid，会记录此状态用于排查。' ;;
esac
OUT="$PROJECT_ROOT/Diagnostics/BT-Sleep-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT" || exit 1
exec > >(tee "$OUT/run.txt") 2>&1
STREAM_PID=''
LIMIT_PID=''
WIFI_RESTORE=''
finish_capture() {
  if [ -n "$WIFI_RESTORE" ]; then
    bounded 8 "$OUT/wifi-restore-on-exit.txt" networksetup -setairportpower "$WIFI_RESTORE" on
    WIFI_RESTORE=''
  fi
  if [ -n "$STREAM_PID" ]; then kill "$STREAM_PID" 2>/dev/null || true; wait "$STREAM_PID" 2>/dev/null || true; STREAM_PID=''; fi
  if [ -n "$LIMIT_PID" ]; then kill "$LIMIT_PID" 2>/dev/null || true; wait "$LIMIT_PID" 2>/dev/null || true; LIMIT_PID=''; fi
  sync
}
trap finish_capture EXIT
trap 'exit 130' INT TERM
bounded() {
  local seconds="$1" file="$2"; shift 2
  "$@" > "$file" 2>&1 &
  local command_pid=$!
  (
    sleep "$seconds"
    if kill -0 "$command_pid" 2>/dev/null; then
      printf '\n[collection timed out after %s seconds]\n' "$seconds" >> "$file"
      kill -TERM "$command_pid" 2>/dev/null || true
      sleep 2
      kill -KILL "$command_pid" 2>/dev/null || true
    fi
  ) &
  local timer_pid=$! rc=0
  wait "$command_pid" || rc=$?
  kill "$timer_pid" 2>/dev/null || true
  wait "$timer_pid" 2>/dev/null || true
  printf '%s exit=%s\n' "$(date '+%F %T %z') $*" "$rc" >> "$OUT/command-status.txt"
  BOUNDED_RC="$rc"
  return 0
}
mark() {
  printf '%s %s\n' "$(date '+%F %T %z')" "$*" | tee -a "$OUT/markers.txt"
}
snapshot() {
  local phase="$1"
  mkdir -p "$OUT/$phase"
  mark "snapshot $phase"
  bounded 10 "$OUT/$phase/usb-plane.txt" ioreg -p IOUSB -l -w0
  bounded 10 "$OUT/$phase/realtek-loader.txt" ioreg -r -c RealtekBluetoothFirmware -l -w0
  bounded 10 "$OUT/$phase/usb-ports.txt" ioreg -r -c AppleUSBHostPort -l -w0
  bounded 12 "$OUT/$phase/bluetooth.json" system_profiler SPBluetoothDataType -json
  bounded 8 "$OUT/$phase/interfaces.txt" ifconfig -a
  bounded 8 "$OUT/$phase/power.txt" pmset -g
  {
    for key in bluetoothExternalDongleFailed bluetoothInternalControllerInfo bluetoothHostControllerSwitchBehavior boot-args opencore-version; do
      nvram "$key" 2>&1
    done
  } > "$OUT/$phase/selected-nvram.txt"
  ps -axo pid,ppid,etime,state,%cpu,comm | awk 'NR==1 || /bluetoothd|BlueTool|airportd|wifid/' > "$OUT/$phase/processes.txt"
}
echo "日志写入：$OUT"
echo '本工具先记录原始故障；确认故障后，尝试先关闭 Wi-Fi、重启蓝牙服务，再恢复 Wi-Fi。'
echo '此操作会短暂断网，不删除已配对设备或已保存的 Wi-Fi。'
sw_vers > "$OUT/system-version.txt"
uname -m >> "$OUT/system-version.txt"
printf '%s\n' "$ACTIVE_BOOT_ARGS" > "$OUT/active-boot-args.txt"
bounded 15 "$OUT/loaded-kexts.txt" kmutil showloaded
bounded 10 "$OUT/sleep-settings.txt" pmset -g custom
bounded 10 "$OUT/power-source.txt" pmset -g batt
bounded 10 "$OUT/disks.txt" diskutil list
bounded 10 "$OUT/chosen-boot.txt" ioreg -p IODeviceTree -n chosen -r -l -w0
{
  shasum -a 256 "$PROJECT_ROOT/EFI/OC/config.plist"
  for cfg in /Volumes/*/EFI/OC/config.plist; do
    [ -f "$cfg" ] && shasum -a 256 "$cfg"
  done
} > "$OUT/mounted-efi-config-hashes.txt" 2>&1
PREDICATE='process == "bluetoothd" OR process == "BlueTool" OR process == "airportd" OR process == "wifid" OR (process == "kernel" AND (eventMessage CONTAINS[c] "RealtekFirmware" OR eventMessage CONTAINS[c] "RealtekBluetooth" OR eventMessage CONTAINS[c] "Bluetooth" OR eventMessage CONTAINS[c] "USB" OR eventMessage CONTAINS[c] "AirportRTW" OR eventMessage CONTAINS[c] "rtw89" OR eventMessage CONTAINS[c] "btlfx"))'
bounded 35 "$OUT/history-before.log" /usr/bin/log show --last 45m --style compact --info --debug --predicate "$PREDICATE"
(
  ulimit -f 131072
  exec /usr/bin/log stream --style compact --level debug --predicate "$PREDICATE"
) > "$OUT/live.log" 2>&1 &
STREAM_PID=$!
# A forgotten capture is bounded; do not install a daemon or keep the Mac awake.
( sleep 1800; kill "$STREAM_PID" 2>/dev/null || true ) &
LIMIT_PID=$!
snapshot before
if [ "$MODE" = --bluetooth ]; then
  echo ''
  echo '基线完成。请保持 Wi-Fi 联网，连接 Enco X3，然后从苹果菜单进入睡眠。'
  echo '唤醒后测试耳机连接、蓝牙搜索和 Wi-Fi 搜索/连接，再回到这里输入：'
else
  echo '已选择“故障已发生”，开始记录并尝试恢复。'
fi
if [ "$MODE" = --bluetooth-now ]; then
  RESULT=1
else
  echo '1 = 蓝牙关闭/卡住/搜不到，或影响 Wi-Fi；2 = 这次正常；q = 结束采集。'
  while :; do
    IFS= read -r RESULT || exit 1
    case "$RESULT" in
      1|故障|失败|不正常|异常|卡住|打不开|搜不到) RESULT=1; break ;;
      2|正常|成功|好了) RESULT=2; break ;;
      q|Q|退出) RESULT=q; break ;;
      *) echo '请输入 1/故障、2/正常，或 q/退出。' ;;
    esac
  done
fi
mark "user_result=$RESULT"
snapshot after
bounded 15 "$OUT/sleep-history.txt" pmset -g log
if [ "$RESULT" = 1 ]; then
  for proc in bluetoothd airportd; do
    PID="$(pgrep -x "$proc" | head -n 1)"
    if [ -n "$PID" ]; then bounded 8 "$OUT/$proc-sample-status.txt" sample "$PID" 3 1 -file "$OUT/$proc-sample.txt"; fi
  done
  bounded 8 "$OUT/hardware-ports.txt" networksetup -listallhardwareports
  WIFI_DEVICE="$(awk '/Hardware Port: (Wi-Fi|AirPort)/ { getline; if ($1 == "Device:") print $2; exit }' "$OUT/hardware-ports.txt")"
  if [ -n "$WIFI_DEVICE" ]; then
    bounded 8 "$OUT/wifi-power-before.txt" networksetup -getairportpower "$WIFI_DEVICE"
    if grep -Eq ': On[[:space:]]*$' "$OUT/wifi-power-before.txt"; then
      WIFI_RESTORE="$WIFI_DEVICE"
      mark "temporarily disable Wi-Fi $WIFI_DEVICE before Bluetooth restart"
      bounded 8 "$OUT/wifi-off.txt" networksetup -setairportpower "$WIFI_DEVICE" off
      sleep 2
    fi
  fi
  mark 'attempt bluetoothd restart with Wi-Fi quiesced where possible'
  bounded 5 "$OUT/recovery-result.txt" killall -TERM bluetoothd
  sleep 8
  snapshot before-wifi-restore
  if [ -n "$WIFI_RESTORE" ]; then
    mark "restore Wi-Fi power on $WIFI_RESTORE"
    bounded 8 "$OUT/wifi-on.txt" networksetup -setairportpower "$WIFI_RESTORE" on
    if [ "$BOUNDED_RC" -eq 0 ]; then WIFI_RESTORE=''; fi
    sleep 8
  fi
  snapshot after-service-restart
  echo '已尝试按顺序重启无线功能，没有重启电脑。请测试蓝牙和 Wi-Fi 后输入：'
  echo '1=两者恢复，2=仍故障；也可直接填写蓝牙和 Wi-Fi 各自的情况。'
  IFS= read -r RECOVERY
  mark "service_restart_result=$RECOVERY"
fi
finish_capture
bounded 35 "$OUT/history-after.log" /usr/bin/log show --last 20m --style compact --info --debug --predicate "$PREDICATE"
printf 'Completed %s\n' "$(date '+%F %T %z')" > "$OUT/complete.txt"
chmod -R a+rX "$OUT"
sync
echo "采集完成，日志保存在本地：$OUT"
echo '即使本次正常，也保留睡眠前后记录；分享前先移除个人信息。'
open "$OUT"

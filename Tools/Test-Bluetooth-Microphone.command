#!/bin/bash
set -u
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  printf '请运行：sudo bash "%s"\n' "$0" >&2
  exit 1
fi
if [ "${1:-}" != --local ]; then
  local_script="$(mktemp /private/tmp/OC-BTMic-Test.XXXXXX)" || exit 1
  cp "$0" "$local_script" || exit 1
  exec /bin/bash "$local_script" --local "$local_script"
fi
local_copy="${2:-}"
log_dir="/Users/Shared/OC-BTMic-Test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$log_dir" || exit 1
printf '日志保存在本机：%s\n测试期间不会自动修改无线或电源设置。\n' "$log_dir"
sw_vers > "$log_dir/system-version.txt"
kmutil showloaded > "$log_dir/loaded-kexts.txt" 2>&1
csrutil status > "$log_dir/sip-status.txt" 2>&1
if [ -f /Volumes/OCDEBUG/Logs/active-profile.txt ]; then
  cp /Volumes/OCDEBUG/Logs/active-profile.txt "$log_dir/usb-profile-reference.txt"
fi
/usr/bin/log stream --style compact --level debug --predicate 'process == "bluetoothd" OR process == "airportd" OR process == "powerd" OR (process == "kernel" AND (eventMessage CONTAINS[c] "USB" OR eventMessage CONTAINS[c] "Realtek" OR eventMessage CONTAINS[c] "AMDMicrophone"))' > "$log_dir/live.log" 2>&1 &
stream_pid=$!
finish() {
  kill "$stream_pid" 2>/dev/null || true
  wait "$stream_pid" 2>/dev/null || true
  case "$local_copy" in /private/tmp/OC-BTMic-Test.*) rm -f "$local_copy" ;; esac
  sync
}
trap finish EXIT
trap 'exit 130' INT TERM
mark() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$1" >> "$log_dir/test-markers.txt"; }
snapshot() {
  phase="$1"
  mark "$phase"
  ioreg -l -w0 > "$log_dir/$phase-ioreg.txt" 2>&1
  ifconfig -a > "$log_dir/$phase-interfaces.txt" 2>&1
  pmset -g assertions > "$log_dir/$phase-assertions.txt" 2>&1
  system_profiler SPBluetoothDataType SPAudioDataType SPUSBDataType -json > "$log_dir/$phase-devices.json" 2>&1 &
  profiler_pid=$!
  (sleep 25; kill -TERM "$profiler_pid" 2>/dev/null || true) &
  timer_pid=$!
  wait "$profiler_pid"
  printf '%s system_profiler_exit=%s\n' "$phase" "$?" >> "$log_dir/capture-status.txt"
  kill "$timer_pid" 2>/dev/null || true
  wait "$timer_pid" 2>/dev/null || true
}
printf '\n先连接 Wi-Fi 和 Enco X3，确认耳机可播放。打开系统设置 → 声音 → 输入，\n选择 AMD Digital Microphone，检查说话时输入音量条是否跳动。完成后按回车。\n'
read -r ignored
printf '填写蓝牙、Wi-Fi、麦克风音量条结果：'
IFS= read -r note
printf '%s\n' "$note" > "$log_dir/before-observation.txt"
snapshot before-sleep
printf '\n现在合盖约 20 秒再打开。桌面恢复后检查耳机能否重连和播放，麦克风音量条是否仍跳动。\n完成后按回车；本阶段先保留 U 盘，方便单独判断睡眠的影响。\n'
mark BEGIN_LID_SLEEP
read -r ignored
printf '填写唤醒后耳机和麦克风结果：'
IFS= read -r note
printf '%s\n' "$note" > "$log_dir/after-sleep-observation.txt"
snapshot after-sleep
printf '\n现在在访达推出 OCDEBUG 并拔盘，保持 Wi-Fi 和耳机播放约 20 秒，\n再把 U 盘插回原接口。观察蓝牙是否中断，完成后按回车。\n'
mark BEGIN_UNPLUG_TEST
read -r ignored
printf '填写拔盘和插回后是否中断、是否自行恢复：'
IFS= read -r note
printf '%s\n' "$note" > "$log_dir/after-unplug-observation.txt"
snapshot after-unplug
pmset -g log > "$log_dir/pmset-history.txt" 2>&1
dmesg > "$log_dir/dmesg.txt" 2>&1
mark CAPTURE_COMPLETE
kill "$stream_pid" 2>/dev/null || true
wait "$stream_pid" 2>/dev/null || true
chmod -R a+rX "$log_dir"
sync
if [ -f /Volumes/OCDEBUG/EFI/OC/config.plist ] && [ -w /Volumes/OCDEBUG ]; then
  mkdir -p /Volumes/OCDEBUG/Logs
  if cp -R "$log_dir" /Volumes/OCDEBUG/Logs/; then
    sync
    printf '已复制到 U 盘 Logs。\n'
  fi
fi
printf 'Saved locally: %s\n' "$log_dir"

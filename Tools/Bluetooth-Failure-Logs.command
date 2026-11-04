#!/bin/bash
set -u
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  printf 'Please run: sudo bash "%s"\n' "$0" >&2
  exit 1
fi
log_dir="/Users/Shared/OC-Bluetooth-Failure-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$log_dir" || exit 1
chmod 755 "$log_dir"
printf '正在采集当前故障，请勿切换蓝牙或 Wi-Fi。日志先保存在本机：%s\n' "$log_dir"
date '+%Y-%m-%d %H:%M:%S %z' > "$log_dir/start-time.txt"
sw_vers > "$log_dir/system-version.txt" 2>&1
if [ -f /Volumes/OCDEBUG/Logs/active-profile.txt ]; then
  cp /Volumes/OCDEBUG/Logs/active-profile.txt "$log_dir/usb-profile-reference.txt"
fi

# Limit potentially blocked diagnostics; never stop bluetoothd or a driver.
capture() {
  filename="$1"
  seconds="$2"
  shift 2
  "$@" > "$log_dir/$filename" 2>&1 &
  command_pid=$!
  (
    sleep "$seconds"
    if kill -0 "$command_pid" 2>/dev/null; then
      printf '%s timed out after %ss\n' "$filename" "$seconds" >> "$log_dir/capture-status.txt"
      kill -TERM "$command_pid" 2>/dev/null || true
      sleep 2
      kill -KILL "$command_pid" 2>/dev/null || true
    fi
  ) &
  timer_pid=$!
  wait "$command_pid"
  command_status=$?
  kill "$timer_pid" 2>/dev/null || true
  wait "$timer_pid" 2>/dev/null || true
  printf '%s exit=%s\n' "$filename" "$command_status" >> "$log_dir/capture-status.txt"
}

capture usb.txt 15 ioreg -p IOUSB -l -w0
capture ioreg.txt 20 ioreg -l -w0
capture power-assertions.txt 10 pmset -g assertions
capture power-settings.txt 10 pmset -g custom
capture interfaces.txt 10 ifconfig -a
capture loaded-kexts.txt 20 kmutil showloaded
capture recent-history.log 45 /usr/bin/log show --last 30m --style compact --info --debug --predicate 'process == "bluetoothd" OR process == "airportd" OR process == "powerd" OR (process == "kernel" AND (eventMessage CONTAINS[c] "USB" OR eventMessage CONTAINS[c] "XHC" OR eventMessage CONTAINS[c] "Bluetooth" OR eventMessage CONTAINS[c] "Realtek" OR eventMessage CONTAINS[c] "rtw"))'
capture devices.json 25 system_profiler SPBluetoothDataType SPUSBDataType SPAudioDataType -json
capture dmesg.txt 10 dmesg
date '+%Y-%m-%d %H:%M:%S %z CAPTURE_COMPLETE' > "$log_dir/complete.txt"
chmod -R a+rX "$log_dir"
sync
if [ -f /Volumes/OCDEBUG/EFI/OC/config.plist ] && [ -w /Volumes/OCDEBUG ]; then
  mkdir -p /Volumes/OCDEBUG/Logs
  if cp -R "$log_dir" /Volumes/OCDEBUG/Logs/; then
    sync
    printf '\n已复制到 U 盘：/Volumes/OCDEBUG/Logs/%s\n' "$(basename "$log_dir")"
  else
    printf '\n复制失败，本机副本仍在：%s\n' "$log_dir"
  fi
fi
printf 'Saved locally: %s\n' "$log_dir"

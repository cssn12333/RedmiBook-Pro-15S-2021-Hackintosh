#!/bin/bash
set -u
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  printf '请运行：sudo bash "%s"\n' "$0" >&2
  exit 1
fi
script_dir="$(cd "$(dirname "$0")" && pwd)"
usb_root="$(cd "$script_dir/.." && pwd)"
source_kext="$usb_root/Drivers/AMDMicrophone.kext"
target_kext="/Library/Extensions/AMDMicrophone.kext"
log_dir="/Users/Shared/OC-Microphone-Install-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$log_dir" || exit 1
chmod 755 "$log_dir"
exec > >(tee -a "$log_dir/install.log") 2>&1
printf '日志：%s\n' "$log_dir"
if [ "$(uname -m)" != x86_64 ] || [ "$(sw_vers -productVersion | cut -d. -f1)" != 15 ]; then
  printf '本安装工具只为当前 Intel 架构 macOS 15 测试配置准备。未安装。\n'
  exit 1
fi
ioreg -p IOService -l -w0 > "$log_dir/ioreg-before.txt"
if ! grep -q 'pci1022,15e2' "$log_dir/ioreg-before.txt"; then
  printf '未检测到 AMD ACP 1022:15E2，未安装。\n'
  exit 1
fi
if [ ! -f "$source_kext/Contents/MacOS/AMDMicrophone" ]; then
  printf '未找到 U 盘内的麦克风驱动。未安装。\n'
  exit 1
fi
actual_hash="$(shasum -a 256 "$source_kext/Contents/MacOS/AMDMicrophone" | awk '{print $1}')"
if [ "$actual_hash" != 723267c2c7aa3ae4b17248425370c340af5cc9cb36b5e559ea2b6da1e3fbc780 ]; then
  printf '驱动文件校验不一致，未安装。\n'
  exit 1
fi
csrutil status > "$log_dir/sip-status.txt" 2>&1
cat "$log_dir/sip-status.txt"
if ! grep -Eiq 'Kext Signing:[[:space:]]*disabled|System Integrity Protection status:[[:space:]]*disabled' "$log_dir/sip-status.txt"; then
  printf '\n当前未允许第三方内核驱动。请先使用本项目配置启动（csr-active-config=01000000），再运行此工具。未安装。\n'
  exit 1
fi
if [ -L "$target_kext" ]; then
  printf '目标是符号链接，停止以避免修改其他位置。\n'
  exit 1
fi
if [ -e "$target_kext" ]; then
  old_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$target_kext/Contents/Info.plist" 2>/dev/null || true)"
  if [ "$old_identifier" != com.qhuyduong.AMDMicrophone ]; then
    printf '同名目录不是预期的麦克风驱动，未覆盖。\n'
    exit 1
  fi
  mv "$target_kext" "$log_dir/AMDMicrophone-before.kext" || exit 1
fi
ditto "$source_kext" "$target_kext" || exit 1
chown -R root:wheel "$target_kext" || exit 1
find "$target_kext" -type d -exec chmod 755 {} \;
find "$target_kext" -type f -exec chmod 644 {} \;
chmod 755 "$target_kext/Contents/MacOS/AMDMicrophone"
touch /Library/Extensions
printf '\n正在请求加载麦克风驱动……\n'
kmutil load -p "$target_kext" > "$log_dir/kmutil-load.txt" 2>&1
load_status=$?
cat "$log_dir/kmutil-load.txt"
printf 'load_request_exit=%s\n' "$load_status" > "$log_dir/result.txt"
printf '驱动已复制到系统扩展目录；实际加载和录音效果仍需重启后验证。\n'
printf '请查看 系统设置 → 隐私与安全性，若有阻止驱动/系统软件的提示，允许该麦克风驱动。\n'
printf '然后保存工作、手动重新启动一次，继续使用同一份EFI启动。\n'
printf '重启后在声音输入中找 AMD Digital Microphone，检查说话时输入音量条是否跳动。\n'
chmod -R a+rX "$log_dir"
sync
if [ -d "$usb_root/Logs" ] && [ -w "$usb_root/Logs" ]; then
  cp -R "$log_dir" "$usb_root/Logs/" || true
  sync
fi
printf 'Saved locally: %s\n' "$log_dir"

#!/bin/bash
set -u
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  printf '请运行：sudo bash "%s"\n' "$0" >&2
  exit 1
fi
target_kext="/Library/Extensions/AMDMicrophone.kext"
if [ ! -d "$target_kext" ] || [ -L "$target_kext" ]; then
  printf '未找到可卸载的 AMDMicrophone.kext。\n'
  exit 1
fi
identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$target_kext/Contents/Info.plist" 2>/dev/null || true)"
if [ "$identifier" != com.qhuyduong.AMDMicrophone ]; then
  printf '驱动标识不符合预期，未修改。\n'
  exit 1
fi
backup_dir="/Users/Shared/OC-Microphone-Uninstall-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir" || exit 1
mv "$target_kext" "$backup_dir/AMDMicrophone.kext" || exit 1
touch /Library/Extensions
kmutil unload -b com.qhuyduong.AMDMicrophone > "$backup_dir/kmutil.txt" 2>&1
status=$?
cat "$backup_dir/kmutil.txt"
printf '驱动已从加载位置移出，保存在：%s\n卸载请求退出码：%s\n请手动重新启动。\n' "$backup_dir" "$status"
printf '如要恢复安装前旧版，请从此前 OC-Microphone-Install 目录找 AMDMicrophone-before.kext；本工具未自动还原旧驱动。\n'

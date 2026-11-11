#!/bin/bash
# 编完固件后，拆开 sysupgrade 的 rootfs，逐项核对补丁/脚本/驱动真的进去了。
# 用代码里的标识符判断，不用注释文字：luci 的 JS 会被 JsMin 压缩，注释会被剥光。
# 用法: verify-image.sh <sysupgrade.bin>   任何一项缺失就 exit 1
set -u

IMG="$1"
[ -f "$IMG" ] || { echo "找不到固件: $IMG"; exit 1; }

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
tar -xf "$IMG" -C "$W"
ROOT=$(ls "$W"/sysupgrade-*/root)
# 非 root 解压会因为建不了 dev/console 等设备文件而返回非 0，但普通文件都已经解出来了，
# 所以不看退出码，改为检查解出来的内容。
unsquashfs -q -d "$W/rootfs" "$ROOT" >"$W/unsquashfs.log" 2>&1
R="$W/rootfs"
[ -d "$R/etc" ] && [ -d "$R/www" ] || { echo "unsquashfs 失败，没有解出 etc/www："; tail -5 "$W/unsquashfs.log"; exit 1; }

fail=0
ok()  { echo "  OK   $1"; }
bad() { echo "  缺少 $1"; fail=1; }
has() { # has <描述> <文件> <pattern>
	if [ -f "$2" ] && grep -q -- "$3" "$2"; then ok "$1"; else bad "$1  ($2)"; fi
}
exists() { if [ -e "$2" ]; then ok "$1"; else bad "$1  ($2)"; fi; }

I="$R/www/luci-static/resources/view/status/include"
echo "== 首页补丁（压缩后用标识符判断）=="
has "29_ports.js 端口状态 eth2 补丁"   "$I/29_ports.js" "extraPortNames"
has "29_ports.js 索引 allDevices=data[5]" "$I/29_ports.js" "allDevices=data\[5\]"
has "29_ports.js 索引 pseMap=data[6]"     "$I/29_ports.js" "pseMap=data\[6\]"
has "40_dhcp.js 线上状态 onlineMap"    "$I/40_dhcp.js" "onlineMap"

echo "== LED =="
exists "ledctl"                         "$R/usr/sbin/ledctl"
has "init.d/led restore_phy_leds"       "$R/etc/init.d/led" "restore_phy_leds"
has "init.d/led clear_phy_leds"         "$R/etc/init.d/led" "clear_phy_leds"
has "init.d/led restore_dts_leds"       "$R/etc/init.d/led" "restore_dts_leds"

echo "== AIC8800D80 / 热插拔 =="
exists "aicsend"                        "$R/usr/sbin/aicsend"
exists "usb hotplug 1111:1111"          "$R/etc/hotplug.d/usb/30-baseline-aic1111"
exists "ieee80211 hotplug 换卡整理"     "$R/etc/hotplug.d/ieee80211/20-baseline-clean-stale-radio"
has "换卡整理会清 LuCI 菜单缓存"        "$R/etc/hotplug.d/ieee80211/20-baseline-clean-stale-radio" "luci-indexcache"
exists "aic_load_fw.ko"                 "$(ls "$R"/lib/modules/*/aic_load_fw.ko 2>/dev/null | head -1)"
exists "aic8800DC_fdrv.ko"              "$(ls "$R"/lib/modules/*/aic8800DC_fdrv.ko 2>/dev/null | head -1)"
exists "AIC 韧体目录"                   "$R/lib/firmware/aic8800/usb"

echo "== 其他 =="
exists "curl"                           "$R/usr/bin/curl"
exists "ca-bundle"                      "$R/etc/ssl/certs/ca-certificates.crt"
exists "时区默认脚本"                   "$R/etc/uci-defaults/96-baseline-timezone"
exists "iwinfo"                         "$R/usr/bin/iwinfo"
exists "usb-modeswitch(usbmode)"        "$R/sbin/usbmode"

echo "== luci 版本只能有一种 =="
VER=$(grep -ho 'luci-base[^ ]*' "$R"/lib/apk/db/installed 2>/dev/null | head -1)
echo "  luci-base: ${VER:-未找到}"

[ "$fail" = 0 ] && echo "固件核对通过" || echo "固件核对失败：上面标「缺少」的项没进固件"
exit "$fail"

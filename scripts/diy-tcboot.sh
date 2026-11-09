#!/bin/bash
# XG-040G-MD (bell 机型 / openwrt-25.12) 自定义改动
# 用法：在 openwrt 源码根目录、feeds update/install 之后执行
#   bash <配置仓库>/scripts/diy-tcboot.sh <配置仓库目录>
set -e

REPO_DIR="$(readlink -f "${1:-$(dirname "$0")/..}")"
CUSTOM="$REPO_DIR/custom"
[ -f ./rules.mk ] && [ -d ./package ] || { echo "请在 openwrt 源码根目录执行"; exit 1; }

step() { echo; echo "==== $* ===="; }

step "1. 默认 LAN 地址 192.168.8.1、主机名 XG-040G-MD"
sed -i 's/192\.168\.1\.1/192.168.8.1/g' package/base-files/files/bin/config_generate
sed -i "s/hostname='OpenWrt'/hostname='XG-040G-MD'/" package/base-files/files/bin/config_generate
grep -n "192.168.8.1\|hostname='XG-040G-MD'" package/base-files/files/bin/config_generate

step "2. 默认网口：网口4(lan4)=WAN，网口1(2.5G=eth1)、网口2(lan2)、网口3(lan3)=LAN"
NETF=target/linux/airoha/an7581/base-files/etc/board.d/02_network
# 上游原本：lan2~4=LAN，2.5G(eth1)=WAN；改成 eth1+lan2+lan3=LAN，lan4=WAN
sed -i 's/ucidef_set_interfaces_lan_wan "lan2 lan3 lan4" "eth1"/ucidef_set_interfaces_lan_wan "eth1 lan2 lan3" "lan4"/' "$NETF"
grep -q 'ucidef_set_interfaces_lan_wan "eth1 lan2 lan3" "lan4"' "$NETF" || { echo "02_network 修改失败"; exit 1; }
sed -n '/an7581_setup_interfaces()/,/^}/p' "$NETF"

step "2b. 默认 LED：green:pon 跟随 WAN 口(lan4)连接/收发；internet/los 由 hotplug 脚本控制"
LEDF=target/linux/airoha/an7581/base-files/etc/board.d/01_leds
if ! grep -q 'xg040-custom' "$LEDF"; then
	LEDBLOCK=$(cat <<'EOT'
# xg040-custom: WAN 灯（换 WAN 口时由 portconfig 同步 dev）
case "$board" in
bell,xg-040g-md)
	ucidef_set_led_netdev "wan" "WAN" "green:pon" "lan4" "link tx rx"
	;;
esac
EOT
)
	perl -0pi -e 'BEGIN { $b = shift @ARGV } s/\nboard_config_flush\n/\n$b\n\nboard_config_flush\n/' "$LEDBLOCK" "$LEDF"
fi
grep -q 'ucidef_set_led_netdev "wan" "WAN" "green:pon" "lan4"' "$LEDF" || { echo "01_leds 修改失败"; exit 1; }

step "3. 首次开机默认设置（中文、Bootstrap、时区、USB 自动挂载）"
mkdir -p files
cp -rf "$CUSTOM/files/." files/
chmod 0755 files/etc/uci-defaults/* 2>/dev/null || true
chmod 0644 files/etc/hotplug.d/iface/* 2>/dev/null || true
ls -lR files/etc/

step "4. 自定义软件包：aic8800、luci-app-autoreboot、luci-app-portconfig"
for p in aic8800 luci-app-autoreboot luci-app-portconfig; do
	rm -rf "package/$p"
	cp -rf "$CUSTOM/package/$p" "package/$p"
done
# feeds 里如果有同名包，删掉避免冲突
rm -rf feeds/luci/applications/luci-app-autoreboot package/feeds/luci/luci-app-autoreboot
chmod 0755 package/luci-app-portconfig/root/usr/sbin/portconfig \
	package/luci-app-portconfig/root/etc/init.d/portconfig \
	package/luci-app-portconfig/root/etc/uci-defaults/90-portconfig \
	package/luci-app-autoreboot/root/etc/init.d/autoreboot \
	package/luci-app-autoreboot/root/etc/uci-defaults/* 2>/dev/null || true

step "5. AIC8800 驱动光盘模式 → 无线网卡模式（usb-modeswitch 规则）"
cp -f "$CUSTOM/usbmode/"* package/utils/usbmode/data/

step "6. 默认主题保持 Bootstrap（移除 Argon，若存在）"
rm -rf package/luci-theme-argon package/luci-app-argon-config
# update-packages.sh 会把 collections 的默认主题改成 argon，这里改回来
sed -i 's/luci-theme-argon/luci-theme-bootstrap/g' $(find feeds/luci/collections/ -type f -name Makefile)
grep -n "luci-theme-bootstrap" feeds/luci/collections/luci/Makefile || true

step "7. turboacc（不含 SFE，使用流量分载 + 全锥形 NAT）"
if [ ! -d package/turboacc ]; then
	curl -fsSL https://raw.githubusercontent.com/chenmozhijin/turboacc/luci/add_turboacc.sh -o /tmp/add_turboacc.sh
	bash /tmp/add_turboacc.sh --no-sfe
fi
ls package/turboacc

echo
echo "==== diy-tcboot.sh 完成 ===="

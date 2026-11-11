#!/bin/bash
# 基准线：尽量还原上游能用固件（xiangtailiang 的 openwrt-25.12 构建），只把默认主题改成 Bootstrap。
# 在 VM 本地编译，不走云端。用来确认「最原版 + Bootstrap」能不能正常访问，
# 之后再一项项往上加自己的功能（加法排查）。
#
# 用法： bash scripts/build-baseline.sh prepare|build|all
#
# 与上游原版相比只有三处不同：
#   1) 默认主题 Argon → Bootstrap（不装 argon，也不改 collections 的默认主题）
#   2) 去掉配置里写死的 CCACHE_DIR（原来是云端路径 /mnt/openwrt/ccache，不影响固件内容）
#   3) feeds 固定在原版固件构建当天的提交（原版用的是浮动的 master，今天的 luci 和这版核心对不上）
# 其余（源码 a0f613f、config、homeproxy/passwall 第三方包、rust 热修）都照上游。
set -e

REPO_DIR="$(readlink -f "$(dirname "$0")/..")"
OPENWRT_DIR="${OPENWRT_DIR:-$HOME/work-xg040/openwrt-2512}"
OPENWRT_REF="${OPENWRT_REF:-a0f613fae7a309dab6516023f556d1323c2b248b}"
LOG_DIR="${LOG_DIR:-$HOME/work-xg040/logs-baseline}"
mkdir -p "$LOG_DIR"

prepare() {
	cd "$OPENWRT_DIR"
	echo "==== 重置源码到 $OPENWRT_REF ===="
	git reset -q --hard "$OPENWRT_REF"
	git clean -fdq        # 只清未跟踪文件；dl/build_dir/staging_dir 保留
	rm -rf files tmp

	echo "==== feeds（固定在原版固件构建当天）===="
	cat > feeds.conf.default <<'EOF'
src-git packages https://github.com/openwrt/packages.git^a16d10144dd3f854a57d9a512dfa84f990b45d65
src-git luci https://github.com/openwrt/luci.git^a450f0d67c6d9d854ba19e57a1361da8cedd8d98
EOF
	rm -rf feeds package/feeds
	./scripts/feeds update -a
	./scripts/feeds install -a -f
	git -C feeds/luci rev-parse HEAD
	git -C feeds/packages rev-parse HEAD

	echo "==== 第三方包 homeproxy / passwall（上游脚本，去掉 Argon 两段）===="
	( cd package && bash "$REPO_DIR/scripts/baseline/update-packages.sh" )

	echo "==== rust 热修（上游同款）===="
	sed -i 's/--set=llvm.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/' \
		feeds/packages/lang/rust/Makefile

	echo "==== 加法排查：turboacc ===="
	if [ ! -d package/turboacc ]; then
		curl -fsSL https://raw.githubusercontent.com/chenmozhijin/turboacc/luci/add_turboacc.sh -o /tmp/add_turboacc.sh
		bash /tmp/add_turboacc.sh --no-sfe
	fi
	ls package/turboacc

	echo "==== 加法排查：diskman（第三方，取自官方仓库） ===="
	rm -rf package/luci-app-diskman
	D=$(mktemp -d)
	git clone -q --depth=1 https://github.com/lisaac/luci-app-diskman.git "$D/diskman-src"
	cp -r "$D/diskman-src/applications/luci-app-diskman" package/luci-app-diskman
	rm -rf "$D"
	ls package/luci-app-diskman

	echo "==== 加法排查：luci-app-autoreboot（自带包） ===="
	rm -rf package/luci-app-autoreboot
	cp -r "$REPO_DIR/custom/package/luci-app-autoreboot" package/luci-app-autoreboot
	chmod 0755 package/luci-app-autoreboot/root/etc/init.d/autoreboot \
		package/luci-app-autoreboot/root/etc/uci-defaults/* 2>/dev/null || true

	echo "==== 加法排查：默认主机名 XG-040G-MD + fstab 自动挂载默认开 ===="
	sed -i "s/hostname='OpenWrt'/hostname='XG-040G-MD'/" package/base-files/files/bin/config_generate
	grep -n "hostname='XG-040G-MD'" package/base-files/files/bin/config_generate
	mkdir -p files/etc/uci-defaults
	cat > files/etc/uci-defaults/99-baseline-fstab <<'UCIEOF'
#!/bin/sh
[ -f /etc/config/fstab ] || touch /etc/config/fstab
uci -q get fstab.@global[0] >/dev/null || uci -q add fstab global >/dev/null
uci -q batch <<EOF
set fstab.@global[0].anon_mount='1'
set fstab.@global[0].auto_mount='1'
set fstab.@global[0].anon_swap='0'
set fstab.@global[0].check_fs='0'
commit fstab
EOF
exit 0
UCIEOF
	chmod 0755 files/etc/uci-defaults/99-baseline-fstab

	echo "==== 加法排查：网口4(lan4)=WAN，网口1(2.5G=eth1)、网口2(lan2)、网口3(lan3)=LAN ===="
	NETF=target/linux/airoha/an7581/base-files/etc/board.d/02_network
	sed -i 's/ucidef_set_interfaces_lan_wan "lan2 lan3 lan4" "eth1"/ucidef_set_interfaces_lan_wan "eth1 lan2 lan3" "lan4"/' "$NETF"
	grep -q 'ucidef_set_interfaces_lan_wan "eth1 lan2 lan3" "lan4"' "$NETF" || { echo "02_network 修改失败"; exit 1; }
	sed -n '/an7581_setup_interfaces()/,/^}/p' "$NETF"

	echo "==== 加法排查：WAN 灯跟着改到网口4(lan4) ===="
	LEDF=target/linux/airoha/an7581/base-files/etc/board.d/01_leds
	if ! grep -q 'baseline-custom' "$LEDF"; then
		LEDBLOCK=$(cat <<'LEDEOF'
# baseline-custom: WAN 灯（网口4=WAN）
case "$board" in
bell,xg-040g-md)
	ucidef_set_led_netdev "wan" "WAN" "green:pon" "lan4" "link tx rx"
		;;
esac
LEDEOF
)
		perl -0pi -e 'BEGIN { $b = shift @ARGV } s/\nboard_config_flush\n/\n$b\n\nboard_config_flush\n/' "$LEDBLOCK" "$LEDF"
	fi
	grep -q 'ucidef_set_led_netdev "wan" "WAN" "green:pon" "lan4"' "$LEDF" || { echo "01_leds 修改失败"; exit 1; }

	echo "==== 加法排查：默认密码 anytoolab.com ===="
	mkdir -p files/etc/uci-defaults
	cat > files/etc/uci-defaults/98-baseline-password <<'PWEOF'
#!/bin/sh
(echo anytoolab.com; echo anytoolab.com) | passwd root >/dev/null 2>&1
exit 0
PWEOF
	chmod 0755 files/etc/uci-defaults/98-baseline-password

	# 标准 patch 文件（patches/baseline/*.patch），路径相对 openwrt 源码根目录，用 patch -p1 打
	apply_patch() {
		echo "打补丁 $1"
		patch -p1 --forward --no-backup-if-mismatch < "$REPO_DIR/patches/baseline/$1" \
			|| { echo "$1 打补丁失败（源码版本可能变了）"; exit 1; }
	}

	echo "==== 首页端口状态增加 USB 网卡 eth2 ===="
	PORTSJS=feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/29_ports.js
	apply_patch 0001-status-ports-usb-nic.patch
	node --check "$PORTSJS" && echo "29_ports.js 语法OK"

	echo "==== 首页 DHCP 租约表加在线/离线状态（ip neigh，不用过时的 onliner 套件） ===="
	DHCPJS=feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/40_dhcp.js
	apply_patch 0002-status-dhcp-online.patch
	node --check "$DHCPJS" && echo "40_dhcp.js 语法OK"

	echo "==== 加法排查：usb-modeswitch 规则文件 + 注释掉不存在的 airoha/an7581 官方源 ===="
	mkdir -p package/utils/usbmode/data
	cp -f "$REPO_DIR/custom/usbmode/"* package/utils/usbmode/data/

	mkdir -p files/etc/uci-defaults
	cat > files/etc/uci-defaults/97-baseline-apk-fix <<'APKEOF'
#!/bin/sh
# 这块是自订板子，官方从来没有 airoha/an7581 的 targets 套件源，
# 这行必定失败，直接注释掉，其余通用架构源不动
sed -i '\#targets/airoha/an7581/packages/packages.adb# s/^/#/' /etc/apk/repositories.d/distfeeds.list 2>/dev/null
exit 0
APKEOF
	chmod 0755 files/etc/uci-defaults/97-baseline-apk-fix

	echo "==== 加法排查：默认时区改成上海 (Asia/Shanghai, CST-8) ===="
	mkdir -p files/etc/uci-defaults
	cat > files/etc/uci-defaults/96-baseline-timezone <<'TZEOF'
#!/bin/sh
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
uci commit system
exit 0
TZEOF
	chmod 0755 files/etc/uci-defaults/96-baseline-timezone

	echo "==== 加法排查：LED 一键关闭/恢复（ledctl 脚本 + init.d/led 补丁，不碰 LuCI 页面） ===="
	LEDINIT=package/base-files/files/etc/init.d/led
	apply_patch 0003-led-phy-off-restore.patch
	bash -n "$LEDINIT" && echo "init.d/led 语法OK"
	grep -q "$(printf '\015')" "$LEDINIT" && { echo "init.d/led 含 CR 换行"; exit 1; }
	mkdir -p files/usr/sbin
	cp "$REPO_DIR/scripts/baseline/ledctl" files/usr/sbin/ledctl
	chmod 0755 files/usr/sbin/ledctl
	sh -n files/usr/sbin/ledctl || { echo "ledctl 语法错误"; exit 1; }
	grep -q "$(printf '\015')" files/usr/sbin/ledctl && { echo "ledctl 含 CR 换行"; exit 1; }

	echo "==== 加法排查：AIC8800D80 驱动 + 1111:1111 自动切换 + USB 无线卡热插拔整理 ===="
	for p in aic8800 aicsend; do
		rm -rf "package/$p"
		cp -r "$REPO_DIR/custom/package/$p" "package/$p"
	done
	mkdir -p files/etc/hotplug.d/ieee80211 files/etc/hotplug.d/usb
	install -m 0755 "$REPO_DIR/scripts/baseline/20-clean-stale-radio.hotplug" files/etc/hotplug.d/ieee80211/20-baseline-clean-stale-radio
	install -m 0755 "$REPO_DIR/scripts/baseline/30-aic1111.hotplug" files/etc/hotplug.d/usb/30-baseline-aic1111
	for f in files/etc/hotplug.d/ieee80211/20-baseline-clean-stale-radio files/etc/hotplug.d/usb/30-baseline-aic1111; do
		sh -n "$f" || { echo "$f 语法错误"; exit 1; }
		[ "$(tr -cd '\r' < "$f" | wc -c)" = 0 ] || { echo "$f 含 CR 换行"; exit 1; }
	done

	echo "==== .config ===="
	cp -f "$REPO_DIR/config/xg-040g-md-baseline.config" .config
	make defconfig
	cp -f .config "$LOG_DIR/defconfig-final.config"

	echo "==== 检查 ===="
	local k
	for k in CONFIG_TARGET_airoha_an7581_DEVICE_bell_xg-040g-md CONFIG_LINUX_6_12 \
		CONFIG_PACKAGE_luci-theme-bootstrap; do
		grep -q "^$k=y" .config && echo "OK   $k" || { echo "缺少 $k"; exit 1; }
	done
	grep -q '^CONFIG_PACKAGE_luci-theme-argon=y' .config && { echo "不该出现 argon"; exit 1; } || echo "OK   无 argon"
	# 本变体（BASELINE_NO_PROXY=1）故意不装代理软件；默认变体要求必须装
	if [ "${BASELINE_NO_PROXY:-0}" = "1" ]; then
		for k in CONFIG_PACKAGE_luci-app-homeproxy CONFIG_PACKAGE_luci-app-passwall; do
			grep -q "^$k=y" .config && { echo "不该出现 $k"; exit 1; } || echo "OK   无 $k"
		done
	else
		for k in CONFIG_PACKAGE_luci-app-homeproxy CONFIG_PACKAGE_luci-app-passwall; do
			grep -q "^$k=y" .config && echo "OK   $k" || { echo "缺少 $k"; exit 1; }
		done
	fi
	grep -q 'luci-theme-bootstrap' feeds/luci/collections/luci-light/Makefile && echo "OK   luci-light 默认 bootstrap"
	return 0
}

build() {
	cd "$OPENWRT_DIR"
	# 之前的实验改过内核补丁，保险起见让内核按当前文件重来
	make target/linux/clean >/dev/null 2>&1 || true
	# 加法排查：luci-mod-status 里有我们手打的补丁(29_ports.js/40_dhcp.js)，
	# 强制清掉它的 build cache，避免 make -j 偷懒复用没打补丁的旧版本
	make package/feeds/luci/luci-mod-status/clean >/dev/null 2>&1 || true
	# init.d/led 在 base-files 里有手打补丁，一并强制重做
	make package/base-files/clean >/dev/null 2>&1 || true
	# bin/packages 里会残留以前用别的 luci/feeds 版本编出来的 apk；apk 选版本号大的，
	# 旧的 26.312 会盖过今天按 pin 的 feeds 新编的 26.280，补丁就进不了固件。
	# 编译前把 luci 目录整个清空（全部会在这次重新生成），并让 luci-mod-status 重做。
	rm -rf bin/packages/*/luci
	rm -rf build_dir/target-*/luci-mod-status/ipkg-* build_dir/target-*/luci-mod-status/.pkgdir
	make download -j8
	find dl -size -1024c -delete
	make -j"$(nproc)" > "$LOG_DIR/build.log" 2>&1 || {
		echo "编译失败，日志尾部："; tail -40 "$LOG_DIR/build.log"; exit 1; }
	ls -l bin/targets/airoha/an7581/*bell_xg-040g-md*
	bash "$REPO_DIR/scripts/baseline/verify-image.sh" bin/targets/airoha/an7581/*bell_xg-040g-md-squashfs-sysupgrade.bin \
		| tee "$LOG_DIR/verify-image.txt"
	[ "${PIPESTATUS[0]}" = 0 ] || { echo "固件核对没通过，见上"; exit 1; }
}

case "${1:-all}" in
prepare) prepare ;;
build) build ;;
all) prepare; build ;;
*) echo "用法：$0 prepare|build|all"; exit 1 ;;
esac

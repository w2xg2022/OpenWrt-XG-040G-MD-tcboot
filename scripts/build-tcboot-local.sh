#!/bin/bash
# XG-040G-MD (tcboot) 在 VM 本地编译
#
# 用法：
#   bash scripts/build-tcboot-local.sh prepare   # 重置源码 → feeds → 第三方包 → 自定义改动 → defconfig
#   bash scripts/build-tcboot-local.sh build     # 下载源码包 + 编译
#   bash scripts/build-tcboot-local.sh all       # 两步一起
#
# 环境变量：
#   OPENWRT_DIR  openwrt 源码目录（默认 ~/work-xg040/openwrt，来源 xiangtailiang/openwrt main）
#   OPENWRT_REF  固定的源码版本（默认见下）
set -e

REPO_DIR="$(readlink -f "$(dirname "$0")/..")"
# 源码：xiangtailiang/openwrt 的 openwrt-25.12 分支，固定在上游能用固件(2026-10-08 18:20)编译时的版本
OPENWRT_DIR="${OPENWRT_DIR:-$HOME/work-xg040/openwrt-2512}"
OPENWRT_REF="${OPENWRT_REF:-a0f613fae7a309dab6516023f556d1323c2b248b}"
CONFIG_FILE="$REPO_DIR/config/xg-040g-md-tcboot.config"
LOG_DIR="${LOG_DIR:-$REPO_DIR/../logs}"
mkdir -p "$LOG_DIR"

prepare() {
	cd "$OPENWRT_DIR"
	echo "==== 重置源码到 $OPENWRT_REF ===="
	git reset -q --hard "$OPENWRT_REF"
	git clean -fdq        # 只清未跟踪文件；dl/build_dir/staging_dir 等被忽略的目录保留
	rm -rf files package/turboacc

	echo "==== feeds ===="
	cp -f "$REPO_DIR/feeds.conf.default" feeds.conf.default
	./scripts/feeds update -a
	./scripts/feeds install -a -f

	# 不带 homeproxy / passwall / argon，所以不跑上游的 update-packages.sh
	sed -i 's/--set=llvm.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/' \
		feeds/packages/lang/rust/Makefile 2>/dev/null || true

	echo "==== 自定义改动 ===="
	bash "$REPO_DIR/scripts/diy-tcboot.sh" "$REPO_DIR"

	echo "==== .config ===="
	cp -f "$CONFIG_FILE" .config
	make defconfig
	cp -f .config "$LOG_DIR/defconfig-final.config"

	echo "==== 检查关键选项 ===="
	local miss=0 k
	for k in \
		CONFIG_TARGET_airoha_an7581_DEVICE_bell_xg-040g-md \
		CONFIG_LINUX_6_12 \
		CONFIG_PACKAGE_luci-app-turboacc \
		CONFIG_PACKAGE_luci-app-autoreboot \
		CONFIG_PACKAGE_luci-app-portconfig \
		CONFIG_PACKAGE_luci-theme-bootstrap \
		CONFIG_PACKAGE_luci-i18n-base-zh-cn \
		CONFIG_PACKAGE_kmod-fs-ntfs3 \
		CONFIG_PACKAGE_kmod-fs-exfat \
		CONFIG_PACKAGE_kmod-rtw88-8822bu \
		CONFIG_PACKAGE_kmod-rtw88-8821cu \
		CONFIG_PACKAGE_kmod-mt76x2u \
		CONFIG_PACKAGE_kmod-aic8800-usb \
		CONFIG_PACKAGE_usb-modeswitch \
		CONFIG_PACKAGE_kmod-usb-net-rtl8152; do
		if grep -q "^$k=y" .config; then echo "  OK  $k"; else echo "  缺  $k"; miss=1; fi
	done
	for k in luci-theme-argon luci-app-homeproxy luci-app-passwall; do
		if grep -q "^CONFIG_PACKAGE_$k=y" .config; then echo "  不该有  $k"; miss=1; fi
	done
	[ $miss -eq 0 ] || { echo "有选项没生效，请检查"; exit 1; }
}

build() {
	cd "$OPENWRT_DIR"
	echo "==== 下载 ===="
	make download -j8
	find dl -size -1024c -delete
	echo "==== 编译 ===="
	local log="$LOG_DIR/build.log" rc=0
	make -j"$(nproc)" > "$log" 2>&1 || rc=$?
	tail -n 25 "$log"
	if [ $rc -ne 0 ]; then
		grep -n -E 'error:|Error [0-9]|ERROR:' "$log" | grep -v Werror | head -60 > "$LOG_DIR/build-errors.txt" || true
		if grep -q 'package/aic8800 failed to build' "$log"; then
			echo "!!!! AIC8800 驱动编译失败：去掉它继续，其余功能照常出固件（错误见 build-errors.txt）"
			sed -i '/^CONFIG_PACKAGE_kmod-aic8800-usb=y/d;/^CONFIG_PACKAGE_aic8800-usb-firmware=y/d' .config
			echo '# CONFIG_PACKAGE_kmod-aic8800-usb is not set' >> .config
			echo '# CONFIG_PACKAGE_aic8800-usb-firmware is not set' >> .config
			make defconfig
			touch "$LOG_DIR/NO_AIC8800"
			make -j"$(nproc)" || make -j1 V=s
		else
			echo "多线程失败，改单线程 V=s 定位错误"
			make -j1 V=s
		fi
	fi
	ls -l bin/targets/airoha/an7581/*bell_xg-040g-md*
}

case "$1" in
prepare) prepare ;;
build) build ;;
all) prepare; build ;;
*) sed -n '2,12p' "$0"; exit 1 ;;
esac

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

	echo "==== .config ===="
	cp -f "$REPO_DIR/config/xg-040g-md-baseline.config" .config
	make defconfig
	cp -f .config "$LOG_DIR/defconfig-final.config"

	echo "==== 检查 ===="
	local k
	for k in CONFIG_TARGET_airoha_an7581_DEVICE_bell_xg-040g-md CONFIG_LINUX_6_12 \
		CONFIG_PACKAGE_luci-theme-bootstrap CONFIG_PACKAGE_luci-app-homeproxy CONFIG_PACKAGE_luci-app-passwall; do
		grep -q "^$k=y" .config && echo "OK   $k" || { echo "缺少 $k"; exit 1; }
	done
	grep -q '^CONFIG_PACKAGE_luci-theme-argon=y' .config && { echo "不该出现 argon"; exit 1; } || echo "OK   无 argon"
	grep -q 'luci-theme-bootstrap' feeds/luci/collections/luci/Makefile && echo "OK   collections 默认 bootstrap"
}

build() {
	cd "$OPENWRT_DIR"
	# 之前的实验改过内核补丁，保险起见让内核按当前文件重来
	make target/linux/clean >/dev/null 2>&1 || true
	make download -j8
	find dl -size -1024c -delete
	make -j"$(nproc)" > "$LOG_DIR/build.log" 2>&1 || {
		echo "编译失败，日志尾部："; tail -40 "$LOG_DIR/build.log"; exit 1; }
	ls -l bin/targets/airoha/an7581/*bell_xg-040g-md*
}

case "${1:-all}" in
prepare) prepare ;;
build) build ;;
all) prepare; build ;;
*) echo "用法：$0 prepare|build|all"; exit 1 ;;
esac

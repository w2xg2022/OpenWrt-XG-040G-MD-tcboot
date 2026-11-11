#!/bin/bash
# 把 release-notes.template.md 里的 {{变量}} 填上，输出到 stdout。
# 用法: render-release-notes.sh <固件目录> > release-notes.md
#   固件目录：放着 factory.bin / sysupgrade.bin 的地方（算 MD5、取构建时间用）
# 可用环境变量覆盖：REPO_URL SOURCE_REPO SOURCE_BRANCH KNOWN_ISSUES OPENWRT_DIR
set -eu

DIR="${1:?用法: $0 <固件目录>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$HERE/../.." && pwd)"
OPENWRT_DIR="${OPENWRT_DIR:-$HOME/work-xg040/openwrt-2512}"

SYSUP="$(ls "$DIR"/*sysupgrade.bin | head -1)"
[ -f "$SYSUP" ] || { echo "$DIR 里找不到 sysupgrade.bin" >&2; exit 1; }

# 构建时间：固件文件的修改时间（东八区），不是现在的时间
BUILD_TIME="$(TZ=Asia/Shanghai date -r "$SYSUP" '+%Y-%m-%d %H:%M')"

# 内核版本：直接读源码树，不手写
KMAJ="$(sed -n 's/^KERNEL_PATCHVER:=//p' "$OPENWRT_DIR/target/linux/airoha/Makefile")"
KPAT="$(sed -n "s/^LINUX_VERSION-$KMAJ = //p" "$OPENWRT_DIR/target/linux/generic/kernel-$KMAJ")"
KERNEL_VERSION="$KMAJ$KPAT"

# 源码仓库 / 分支 / commit：默认取源码树自己的 origin
SOURCE_REPO="${SOURCE_REPO:-$(git -C "$OPENWRT_DIR" remote get-url origin | sed 's/\.git$//')}"
SOURCE_BRANCH="${SOURCE_BRANCH:-openwrt-25.12}"
SOURCE_COMMIT="$(git -C "$OPENWRT_DIR" rev-parse --short=12 HEAD)"
OPENWRT_BRANCH_VER="${SOURCE_BRANCH#openwrt-}"

REPO_URL="${REPO_URL:-$(git -C "$REPO_DIR" remote get-url origin | sed 's/\.git$//')}"
REPO_COMMIT="$(git -C "$REPO_DIR" rev-parse --short=8 HEAD)"

MD5_LIST="$(cd "$DIR" && md5sum ./*.bin | sed 's# \./# #')"
KNOWN_ISSUES="${KNOWN_ISSUES:-暂无其他已知问题。}"

export BUILD_TIME KERNEL_VERSION SOURCE_REPO SOURCE_BRANCH SOURCE_COMMIT \
       OPENWRT_BRANCH_VER REPO_URL REPO_COMMIT MD5_LIST KNOWN_ISSUES

# 逐个替换，值里可能有 / & 等字符，所以用 awk 的字面替换，不用 sed
awk '
function rep(s, key,    v, i) {
	v = ENVIRON[key]
	while ((i = index(s, "{{" key "}}")) > 0)
		s = substr(s, 1, i - 1) v substr(s, i + length(key) + 4)
	return s
}
{
	n = split("BUILD_TIME KERNEL_VERSION SOURCE_REPO SOURCE_BRANCH SOURCE_COMMIT OPENWRT_BRANCH_VER REPO_URL REPO_COMMIT MD5_LIST KNOWN_ISSUES", k, " ")
	for (j = 1; j <= n; j++) $0 = rep($0, k[j])
	print
}' "$HERE/release-notes.template.md"

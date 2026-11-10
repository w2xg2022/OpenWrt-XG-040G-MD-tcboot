#!/bin/bash
# 用 ImageBuilder 快速出包（几分钟，不重新编译）
#
# 用法：bash scripts/build-ib.sh <ImageBuilder 解压目录> [输出目录]
#
# 软件包清单：config/ib-packages.txt（一行一个，# 开头为注释，-包名 表示不装）
# 覆盖文件：custom/files（首次开机默认设置等）+ custom/ib-overlay（board.d 网口/LED 分配）
# 只改这些就能出新固件；要改驱动、内核或新增 ImageBuilder 里没有的包，才需要完整编译。
set -e

REPO_DIR="$(readlink -f "$(dirname "$0")/..")"
IB_DIR="$(readlink -f "${1:?请给 ImageBuilder 目录}")"
OUT_DIR="$(readlink -m "${2:-$IB_DIR/out}")"
PROFILE="bell_xg-040g-md"

OV="$(mktemp -d)"
trap 'rm -rf "$OV"' EXIT
cp -rf "$REPO_DIR/custom/files/." "$OV/"
cp -rf "$REPO_DIR/custom/ib-overlay/." "$OV/"
chmod 0755 "$OV"/etc/uci-defaults/* "$OV"/etc/board.d/* 2>/dev/null || true
chmod 0644 "$OV"/etc/hotplug.d/iface/* 2>/dev/null || true

PKGS="$(grep -v '^[[:space:]]*#' "$REPO_DIR/config/ib-packages.txt" | xargs)"

mkdir -p "$OUT_DIR"
make -C "$IB_DIR" image \
	PROFILE="$PROFILE" \
	PACKAGES="$PKGS" \
	FILES="$OV" \
	BIN_DIR="$OUT_DIR"

ls -l "$OUT_DIR"

# SPDX-License-Identifier: GPL-2.0-only
#
# XG-040G-MD 网口 LAN/WAN 分配

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for XG-040G-MD port LAN/WAN assignment
LUCI_DEPENDS:=+luci-base
LUCI_PKGARCH:=all

PKG_VERSION:=1.0
PKG_RELEASE:=1

define Package/luci-app-portconfig/conffiles
/etc/config/portconfig
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

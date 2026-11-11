include $(TOPDIR)/rules.mk

PKG_NAME:=aicsend
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/aicsend
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=AIC8800D80 1111:1111 mode switch helper
  DEPENDS:=+libusb-1.0
endef

define Package/aicsend/description
  Sends the vendor-specific SCSI CBW that switches AIC8800D80 clone dongles
  (USB 1111:1111, product 88M80) from fake mass-storage mode to WiFi mode.
  The generic usb_modeswitch StandardEject does not work on these units.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/aicsend.c $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_CPPFLAGS) $(TARGET_LDFLAGS) \
		-o $(PKG_BUILD_DIR)/aicsend $(PKG_BUILD_DIR)/aicsend.c -lusb-1.0
endef

define Package/aicsend/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/aicsend $(1)/usr/sbin/aicsend
endef

$(eval $(call BuildPackage,aicsend))

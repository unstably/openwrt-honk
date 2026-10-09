# SPDX-License-Identifier: MIT
#
# Thin package: installs the OFFICIAL Zakkaus/doona static web UI for Honk.
# Doona is arch-independent; it is served by honk's native_api at /ui/.

include $(TOPDIR)/rules.mk

PKG_NAME:=doona
# Upstream (Zakkaus/doona) release tag we pin:
DOONA_UPSTREAM_VER:=0.1.0-beta.19
# NOTE: the OpenWrt package version must NOT be "0.1.0-beta.19".
# APK (SDK 25.12) validates the version field and rejects a dash-suffix that
# contains dots: "0.1.0-beta.19-r1" -> "ERROR: info field 'version' has invalid
# value: package version is invalid" (Error 99). IPK (24.10) tolerated it, which is
# why only the 25.12 jobs failed. Keep the upstream tag for sourcing only.
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

PKG_SOURCE:=doona-$(DOONA_UPSTREAM_VER).tar.gz
PKG_SOURCE_URL:=https://github.com/Zakkaus/doona/releases/download/v$(DOONA_UPSTREAM_VER)/
PKG_HASH:=5500c2f630bb6cadaa7c2db5758f9ffca3ca86fb47e63e4f145b6bf461173a04

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Zakkaus

include $(INCLUDE_DIR)/package.mk

define Package/doona
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=Doona web UI for Honk
  URL:=https://github.com/Zakkaus/doona
  # doona is arch-independent, but we leave PKGARCH unset so it inherits the target
  # arch. That path is accepted by both IPK (24.10) and APK (25.12), and keeps
  # packaging uniform instead of relying on arch "all"/"noarch" handling under APK.
endef

define Package/doona/description
  Doona is the web control panel bundled with Honk.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/root/usr/share/doona
	$(TAR) --strip-components=1 -C $(PKG_BUILD_DIR)/root/usr/share/doona -xzf $(DL_DIR)/$(PKG_SOURCE)
endef

define Build/Compile
endef

define Package/doona/install
	$(INSTALL_DIR) $(1)/usr/share/doona
	$(CP) $(PKG_BUILD_DIR)/root/usr/share/doona/* $(1)/usr/share/doona/
	$(INSTALL_DIR) $(1)/usr/share/licenses/doona
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/root/usr/share/doona/LICENSE $(1)/usr/share/licenses/doona/LICENSE
endef

$(eval $(call BuildPackage,doona))

# SPDX-License-Identifier: AGPL-3.0-only
#
# Thin OpenWrt feed for Honk on aarch64/x86_64.
# Pins the OFFICIAL prebuilt artifacts:
#   - honk core : Glassyiris/honk  (debug.*.native-api.* "stock" musl tarball)
#   - doona UI  : Zakkaus/doona    (static web bundle, arch-independent)
# No Rust / Node compile happens here.

include $(TOPDIR)/rules.mk

PKG_NAME:=honk
PKG_VERSION:=2026.10.09
PKG_RELEASE:=1

# Release tag on Glassyiris/honk that publishes the "stock" musl tarballs.
HONK_RELEASE_TAG:=debug.2026.10.9.native-api.2
HONK_ASSET_TAG:=debug
HONK_SUFFIX:=-stock

# SHA256 of each prebuilt release tarball (kept in sync with HONK_RELEASE_TAG).
HONK_HASH_X86_64:=d46eecc460ad9f9fdfad30b80828e4b64ec9f94bbcabff942b8fe68d3793f9b2
HONK_HASH_AARCH64:=b706100f6a9ba9879bf2c1e018f64072ebe66f128f8dcb8b8a11d803eefe8174

PKG_LICENSE:=AGPL-3.0-only
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=unstably

ifeq ($(ARCH),x86_64)
  HONK_TARGET:=x86_64-unknown-linux-musl
  HONK_HASH:=$(HONK_HASH_X86_64)
else ifeq ($(ARCH),aarch64)
  HONK_TARGET:=aarch64-unknown-linux-musl
  HONK_HASH:=$(HONK_HASH_AARCH64)
endif

HONK_ASSET:=honk-core-$(HONK_ASSET_TAG)-$(HONK_TARGET)$(HONK_SUFFIX).tar.gz

PKG_SOURCE:=$(HONK_ASSET)
PKG_SOURCE_URL:=https://github.com/Glassyiris/honk/releases/download/$(HONK_RELEASE_TAG)/
PKG_HASH:=$(HONK_HASH)

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/honk
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=Honk transparent proxy core
  URL:=https://github.com/Glassyiris/honk
  DEPENDS:=@(x86_64||aarch64) +doona +ca-bundle +ip-full +ubus +kmod-sched-core +kmod-sched-bpf +kmod-veth +kmod-nft-queue +jsonfilter +jshn +sqlite3-cli +libubox +usign +coreutils-stat +v2ray-geoip +v2ray-geosite +@KERNEL_DEBUG_INFO_BTF
endef

define Package/honk/description
  Honk is a transparent proxy core for OpenWrt x86_64 and aarch64.
  This package bundles the official prebuilt binary and our management glue.
endef

define Package/honk/conffiles
/etc/config/honk
/etc/honk/config.dae
/etc/honk/system.dae
endef

define Build/Prepare
	$(TAR) -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1
endef

define Build/Compile
endef

define Package/honk/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/honk-core $(1)/usr/bin/honk-core

	$(INSTALL_DIR) $(1)/usr/share/licenses/honk
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/LICENSE $(1)/usr/share/licenses/honk/LICENSE

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(CURDIR)/files/honk.config $(1)/etc/config/honk

	$(INSTALL_DIR) $(1)/etc/honk
	$(INSTALL_CONF) $(CURDIR)/files/config.dae $(1)/etc/honk/config.dae
	$(INSTALL_CONF) $(CURDIR)/files/system.dae $(1)/etc/honk/system.dae
	chmod 0444 $(1)/etc/honk/system.dae
	$(INSTALL_DIR) $(1)/etc/honk/state
	chmod 0700 $(1)/etc/honk/state

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(CURDIR)/files/honk.init $(1)/etc/init.d/honk
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) $(CURDIR)/files/90-honk-boot $(1)/etc/uci-defaults/90-honk

	$(INSTALL_DIR) $(1)/usr/share/honk
	$(INSTALL_DATA) $(CURDIR)/files/default-config.dae $(1)/usr/share/honk/default-config.dae
	$(INSTALL_BIN) $(CURDIR)/files/control.sh $(1)/usr/share/honk/control.sh
	$(INSTALL_BIN) $(CURDIR)/files/lock.sh $(1)/usr/share/honk/lock.sh
	$(INSTALL_BIN) $(CURDIR)/files/lifecycle.sh $(1)/usr/share/honk/lifecycle.sh
endef

$(eval $(call BuildPackage,honk))

#!/bin/sh
# honk-setup.sh — honk + doona 一键安装 / 卸载（OpenWrt aarch64 / x86_64）
#
#   安装（全新或升级）:  sh honk-setup.sh install
#   卸载:                sh honk-setup.sh uninstall
#
# 可用环境变量覆盖：
#   TAG=          Release 标签           默认 v2026.10.09-r3
#   ARCH=         目标架构               默认自动检测（OpenWrt 优先，其次 uname -m）
#   HONK_VER=     honk 包版本            默认 2026.10.09-r1
#   DOONA_VER=    doona 包版本           默认 0.1.0-r1
#   MIRROR=       下载镜像前缀           默认 https://github.com
#                 例：MIRROR=https://ghfast.top
#   PURGE=1       卸载时连配置一起删除（默认保留，且已备份）
set -eu

REPO="unstably/openwrt-honk-for-aarch64"
ACTION="${1:-install}"
TAG="${TAG:-v2026.10.09-r3}"
HONK_VER="${HONK_VER:-2026.10.09-r1}"
DOONA_VER="${DOONA_VER:-0.1.0-r1}"
MIRROR="${MIRROR:-https://github.com}"

log() { printf '[honk] %s\n' "$*"; }
die() { printf '[honk] 错误: %s\n' "$*" >&2; exit 1; }

# ---------- 下载（curl / wget / uclient-fetch 三选一）----------
dl() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 15 -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$2" "$1"
    elif command -v uclient-fetch >/dev/null 2>&1; then
        uclient-fetch -q -O "$2" "$1"
    else
        die "找不到下载工具（curl / wget / uclient-fetch 都没有）"
    fi
}

# ---------- 架构检测 ----------
detect_arch() {
    if [ -n "${ARCH:-}" ]; then printf '%s\n' "$ARCH"; return; fi
    if [ -r /etc/os-release ]; then . /etc/os-release 2>/dev/null || true; fi
    case "${OPENWRT_ARCH:-}" in
        aarch64_generic|aarch64_cortex-a53|aarch64_cortex-a72|x86_64)
            printf '%s\n' "$OPENWRT_ARCH"; return ;;
    esac
    case "$(uname -m)" in
        aarch64|arm64) printf 'aarch64_generic\n' ;;
        x86_64|amd64)  printf 'x86_64\n' ;;
        *)             die "不支持的架构: $(uname -m)（可用 ARCH= 手动指定）" ;;
    esac
}

# ---------- 包管理器检测 ----------
detect_pkg() {
    if [ -f /etc/apk/world ] && command -v apk >/dev/null 2>&1; then
        printf 'apk\n'
    elif command -v opkg >/dev/null 2>&1; then
        printf 'opkg\n'
    else
        die "找不到 apk / opkg"
    fi
}

# ---------- 依赖提示（geo 数据缺失会导致 honk 启动失败）----------
check_deps() {
    missing=""
    for p in v2ray-geoip v2ray-geosite; do
        if [ "$PKG" = apk ]; then
            if ! apk info -e "$p" >/dev/null 2>&1; then missing="$missing $p"; fi
        else
            if ! opkg list-installed 2>/dev/null | grep -q "^$p "; then missing="$missing $p"; fi
        fi
    done
    if [ -n "$missing" ]; then
        log "注意：尚未安装$missing，将尝试从已配置软件源安装。"
        log "若报 unsatisfiable，请添加提供它们的软件源（如 kenzok8/wall）后重试。"
    fi
}

do_install() {
    ARCH="$(detect_arch)"
    PKG="$(detect_pkg)"

    if [ "$PKG" = apk ]; then
        HONK_FILE="honk-${HONK_VER}-${ARCH}.apk"
        DOONA_FILE="doona-${DOONA_VER}-${ARCH}.apk"
    else
        HONK_FILE="honk_${HONK_VER}_${ARCH}.ipk"
        DOONA_FILE="doona_${DOONA_VER}_${ARCH}.ipk"
    fi
    BASE="${MIRROR}/${REPO}/releases/download/${TAG}"

    log "架构 ${ARCH} · 包管理器 ${PKG} · Release ${TAG}"
    check_deps

    TMP="$(mktemp -d 2>/dev/null || echo "/tmp/honk-setup.$$")"
    mkdir -p "$TMP"

    for f in "$HONK_FILE" "$DOONA_FILE"; do
        log "下载 $f"
        if ! dl "$BASE/$f" "$TMP/$f"; then
            die "下载失败: $BASE/$f
  可尝试：MIRROR=https://ghfast.top sh $0 install"
        fi
    done

    log "安装中…"
    if [ "$PKG" = apk ]; then
        apk add --allow-untrusted "$TMP/$HONK_FILE" "$TMP/$DOONA_FILE"
    else
        opkg install "$TMP/$HONK_FILE" "$TMP/$DOONA_FILE"
    fi
    rm -rf "$TMP"

    # 升级场景：此前已启用则恢复运行，避免装完反而断网
    was_enabled=0
    was_init=0
    if [ -f /etc/config/honk ]; then
        was_enabled="$(uci -q get honk.main.enabled || echo 0)"
        was_init="$(uci -q get honk.main.initialized || echo 0)"
    fi
    if [ "$was_enabled" = 1 ] && [ "$was_init" = 1 ]; then
        log "检测到此前已启用，恢复开机自启并启动…"
        /etc/init.d/honk enable >/dev/null 2>&1 || true
        /etc/init.d/honk start || log "启动失败，请用 logread 查看"
    else
        log "全新安装：为安全起见未自动启动（无订阅时启动会接管全部流量）。"
    fi

    lanip="$(uci -q get network.lan.ipaddr || echo '<路由器IP>')"
    log "完成。管理面板 http://${lanip}:9527"
    log "首次使用请先在面板完成初始化（设置管理员账号 → 添加订阅 → 启用）。"
}

do_uninstall() {
    PKG="$(detect_pkg)"

    log "停止并禁用 honk…"
    if [ -x /etc/init.d/honk ]; then
        /etc/init.d/honk stop >/dev/null 2>&1 || true
        /etc/init.d/honk disable >/dev/null 2>&1 || true
    fi

    BK="/root/honk-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BK"
    if [ -f /etc/config/honk ]; then cp -a /etc/config/honk "$BK/"; fi
    if [ -d /etc/honk ]; then cp -a /etc/honk "$BK/" 2>/dev/null || true; fi
    log "配置已备份到 $BK"

    log "卸载 honk / doona…"
    if [ "$PKG" = apk ]; then
        apk del honk >/dev/null 2>&1 || true
        apk del doona >/dev/null 2>&1 || true
        apk del luci-app-honk >/dev/null 2>&1 || true
    else
        opkg remove honk >/dev/null 2>&1 || true
        opkg remove doona >/dev/null 2>&1 || true
        opkg remove luci-app-honk >/dev/null 2>&1 || true
    fi

    rm -rf /etc/honk/state /usr/share/honk /usr/share/doona
    rm -f /etc/uci-defaults/90-honk
    rm -rf /tmp/honk-setup.* /tmp/honk.lock

    if [ "${PURGE:-0}" = 1 ]; then
        rm -rf /etc/honk /etc/config/honk
        log "PURGE=1：配置已删除（备份仍在 $BK）"
    else
        log "已保留 /etc/config/honk 与 /etc/honk（备份于 $BK）"
        log "如需彻底清除：PURGE=1 sh $0 uninstall"
    fi
    log "完成。虚拟接口 dae0 与残留规则将在重启后彻底消失。"
}

case "$ACTION" in
    install|i)   do_install ;;
    uninstall|remove|u) do_uninstall ;;
    *) die "用法: sh $0 install|uninstall" ;;
esac

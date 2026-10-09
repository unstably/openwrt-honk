# openwrt-honk (thin)

为 OpenWrt **aarch64 / x86_64** 打包的 [honk](https://github.com/Glassyiris/honk) 透明代理。
这是一个**极薄** feed：本仓库**不编译任何 Rust / Node 代码**，只把官方预编译产物和我们的管理 glue 包成 OpenWrt 包。

## 直接 pin 的官方产物

| 组件 | 来源 | 形式 |
| :--- | :--- | :--- |
| honk core 二进制 | [`Glassyiris/honk`](https://github.com/Glassyiris/honk) | 预编译 `*-stock` musl tarball（按 tag + SHA256 锁定） |
| Doona 前端 UI | [`Zakkaus/doona`](https://github.com/Zakkaus/doona) | 预编译静态包（按 version + SHA256 锁定） |

好处：甩开中间商（不再 fork 编译 honk/doona），上游发版后只需在 `honk/Makefile` 改
`HONK_RELEASE_TAG` / `HONK_HASH_*`，在 `doona/Makefile` 改 `DOONA_UPSTREAM_VER` / `PKG_HASH` 即可合入。

## 包

- **`honk`** — `honk-core` 二进制 + 管理脚本（`control.sh` / `lifecycle.sh` / `lock.sh` / `honk.init` / `90-honk-boot`）
  以及默认配置 `config.dae` / `system.dae`。
  - 依赖 `doona`（UI）、`ca-bundle`、`ip-full`、`kmod-sched-bpf`、`kmod-veth`、`kmod-nft-queue` 以及
    `v2ray-geoip` / `v2ray-geosite`（honk-core 启动时从 `DAE_LOCATION_ASSET=/usr/share/v2ray` 加载 geo 数据）。
- **`doona`** — 纯静态前端，安装到 `/usr/share/doona`，由 honk 的 `native_api` 在
  `http://<路由器IP>:9527` 提供管理面板。**没有 LuCI 应用**，管理全部走 Doona Web UI。

## 已固化的 geodata 修复

默认 `config.dae` 的 `assets` 段使用：

```dae
assets {
    route: direct
    geoip:   'https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat'
    geosite: 'https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat'
}
```

`route: direct` 让地理数据下载走路由器自身出网而非代理节点，并指向 jsdelivr 镜像，
修复了在中国大陆直连 `raw.githubusercontent.com` 时被墙导致的
`geodata_update_failed` / `bootstrap_unavailable` 报错。

> ⚠️ **升级时这条修复不会自动生效**。`config.dae` 是 conffiles，只要你改过它（例如通过面板
> 加过订阅），`apk` 就会保留你的版本，把新版写成 `config.dae.apk-new`——新版里的 jsdelivr
> 地址因此不会进来。升级后请确认 `assets` 段里有上面那两行，没有就补上。
> 下面这条命令只动 `assets` 段，订阅 / group / dns 原样保留，且可重复执行：

```sh
grep -q "cdn.jsdelivr.net/gh/MetaCubeX" /etc/honk/config.dae || sed -i "/^assets {/,/^}/ s|^    route: direct$|    route: direct\n    geoip: 'https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat'\n    geosite: 'https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat'|" /etc/honk/config.dae
/etc/init.d/honk stop && sleep 8 && /etc/init.d/honk start
```

> 重启要 `stop` 后等几秒再 `start`：honk 停止时要卸载 eBPF 钩子，`dae0` 虚拟接口不会立刻消失，
> 立刻 `start` 会撞 `dae0 already exists` 而静默失败（服务没起来却不报错）。

## 一键安装

在路由器 SSH 里执行（脚本会自动识别架构 `aarch64 / x86_64` 与包体系 `apk / opkg`，下载对应 Release 包并安装）：

```sh
curl -fsSL https://cdn.jsdelivr.net/gh/unstably/openwrt-honk-for-aarch64@aarch64-rk356x/honk-setup.sh -o /tmp/honk-setup.sh && sh /tmp/honk-setup.sh install
```

> `raw.githubusercontent.com` 在国内常被墙，所以默认走 jsdelivr CDN。若 CDN 未刷新可改用
> `https://raw.githubusercontent.com/unstably/openwrt-honk-for-aarch64/aarch64-rk356x/honk-setup.sh`，
> 或直接复制下方折叠区里的完整脚本到路由器执行。

脚本行为：

- 架构取自 `OPENWRT_ARCH`（`/etc/os-release`），兜底 `uname -m`；`aarch64` 默认用 `aarch64_generic`。
- 包体系：`/etc/apk/world` 存在 → `apk`（OpenWrt/iStoreOS 25.12+），否则 `opkg`（24.10）。
- **升级场景**会自动恢复原来的运行状态（此前 `enabled=1` 且已初始化 → 装完自动 enable + start），避免装完反而断网。
- **全新安装**默认不自动启动（没订阅就启动会接管全部流量），装完提示你先到面板初始化。

## 一键卸载

```sh
curl -fsSL https://cdn.jsdelivr.net/gh/unstably/openwrt-honk-for-aarch64@aarch64-rk356x/honk-setup.sh -o /tmp/honk-setup.sh && sh /tmp/honk-setup.sh uninstall
```

脚本行为：

- 先 `stop` + `disable` 服务，再把 `/etc/config/honk` 与 `/etc/honk` 备份到 `/root/honk-backup-<时间戳>/`。
- 卸载 `honk`、`doona`（以及旧版残留的 `luci-app-honk`）。
- 清理 `/etc/honk/state`（初始化状态）、`/usr/share/honk`、`/usr/share/doona`、锁文件与残留 uci-defaults。
- 默认**保留配置**方便重装；要连配置一起清：`PURGE=1 sh /tmp/honk-setup.sh uninstall`。
- 不动 `v2ray-geoip` / `v2ray-geosite`（它们属于独立包，可能有别的软件在用）。

### 可选变量

| 变量 | 说明 | 默认 |
| :--- | :--- | :--- |
| `TAG=` | Release 标签 | `v2026.10.09-r3` |
| `ARCH=` | 强制指定架构（`aarch64_generic` / `aarch64_cortex-a53` / `aarch64_cortex-a72` / `x86_64`） | 自动检测 |
| `MIRROR=` | 下载镜像前缀，例：`MIRROR=https://ghfast.top` | `https://github.com` |
| `PURGE=1` | 卸载时连配置一起删除 | 关闭 |

例：`TAG=v2026.10.09-r3 MIRROR=https://ghfast.top sh /tmp/honk-setup.sh install`

<details>
<summary>完整脚本（<code>honk-setup.sh</code>，CDN 不可用时可直接复制）</summary>

```sh
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

# ---------- 等旧进程的 dae0 虚拟接口消失（最多 30s）----------
# honk 停止时要卸载 eBPF 钩子并清理 dae0，这段时间内启动会撞
# "dae0 already exists" 而失败，所以升级/重启前必须等它释放。
wait_for_dae0_gone() {
    i=0
    while ip link show dae0 >/dev/null 2>&1; do
        i=$((i + 1))
        [ "$i" -ge 30 ] && break
        sleep 1
    done
    [ "$i" -gt 0 ] && log "已等待 ${i}s 让旧进程释放 dae0"
    return 0
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
        # 升级时旧进程还在卸载 eBPF 钩子，dae0 要几秒才消失。此时 start 会报
        # "dae0 already exists" 并静默失败（服务显示没起来但没报错），必须等它清理完。
        wait_for_dae0_gone
        /etc/init.d/honk start || log "启动失败，请用 logread 查看"
        sleep 3
        if ! ip link show dae0 >/dev/null 2>&1; then
            log "警告：honk 似乎未成功启动（dae0 未出现），请用 logread 查看"
        fi
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
        wait_for_dae0_gone
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
```

</details>

## 手动安装

若不想用脚本：

1. 在路由器上添加本 feed 的 Release 源（见 GitHub Releases 里对应的
   `aarch64_generic` APK 与 `APKINDEX`）。
2. `apk update && apk add honk doona`（若未签名需 `apk add --allow-untrusted ...`）。
3. 浏览器打开 `http://<路由器IP>:9527` → 初始化（设置管理员账号）→ 添加订阅 → 启用。

## 构建 / 发布

- 推 `v*` tag 或在 Actions 里 `workflow_dispatch` 触发 `.github/workflows/build.yml`。
- 矩阵：`aarch64_cortex-a53` / `aarch64_cortex-a72` / `aarch64_generic` / `x86_64` ×
  SDK `24.10`（IPK）/ `25.12`（APK）。
- 构建仅生成包封装与 glue，honk / doona 二进制仍是官方原包。

## 升级版本

1. 在 `honk/Makefile` 更新 `HONK_RELEASE_TAG` 与 `HONK_HASH_X86_64` / `HONK_HASH_AARCH64`
   （哈希务必从对应 tarball 实算，CI 会校验）。
2. 在 `doona/Makefile` 更新 `DOONA_UPSTREAM_VER`（上游 tag，决定下载 URL 与 tarball 文件名）
   与 `PKG_HASH`。
   ⚠️ `PKG_VERSION` 是 OpenWrt 包版本，必须与上游 tag 解耦：APK（SDK 25.12）要求版本为纯数字
   点分且短横线后缀内不能含点，例如上游 `v0.1.0-beta.19` 对应 `PKG_VERSION:=0.1.0`。
   若直接把 `0.1.0-beta.19` 用作 `PKG_VERSION`，25.12 构建会报
   `ERROR: info field 'version' has invalid value: package version is invalid`（IPK 24.10 不报错）。
3. 提交并打 `v*` tag 触发 CI。

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

## 安装（iStoreOS / OpenWrt 25.12 APK）

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

# X-WRT for NanoPi R4S DDR3 1GB（内置 dae）

让 NanoPi R4S 1G DDR3 版也能运行 X-WRT 的固件：系统保持官方 X-WRT 不变，引导区替换为 immortalwrt 的 U-Boot（支持 DDR3/LPDDR4 自动识别）。

## 固件特点

- 官方不支持的 **1G DDR3 版可正常启动**；2G LPDDR4 版同样可用（U-Boot 自动识别内存）
- 系统与官方 X-WRT 一致：LuCI 界面、软件包、默认地址 `192.168.15.1`
- 引导区使用 rkbin DDR 初始化，自动检测 DDR3 / LPDDR3 / LPDDR4
- sysupgrade 升级不会覆盖引导区，1G 兼容性可长期保持
- 同时发布 squashfs 和 ext4 两种格式，均为 `.img.gz` + `.sha256`

## 内置 dae 支持

本版本在 X-WRT 基础上额外内置：

- 内核 BTF（`/sys/kernel/btf/vmlinux`）、`BPF_EVENTS`、`KPROBE_EVENTS`
- `kmod-sched-bpf`、`kmod-veth`、`kmod-xdp-sockets-diag`、`kmod-sched-core`、`kmod-nft-tproxy`
- `daed`（官方 Web 面板）、`dae`、`luci-app-daede`（kenzok8 源，与 dae 2.x 配套）

## 下载与刷写

固件发布在 [Releases](https://github.com/ChunY1n/r4sxwrt/releases)，下载 `.img.gz` 后用 balenaEtcher 或 `dd` 刷入 SD 卡即可。

## 手动触发编译

打开 Actions → **Build X-WRT R4S DDR3 (with dae)** → Run workflow，可指定：

- X-WRT 标签（默认 `latest` = 自动取最新 26.04 标签，也可以手动指定）
- immortalwrt 版本（默认 `25.12.1`，用于提取 DDR3 兼容 U-Boot）

编译约需 2~3 小时，完成后在运行页面下载 `xwrt-r4s-ddr3-firmware` 工件。

## 自动发布

- 编译成功后会**自动发布到 GitHub Releases**（tag 命名 `xwrt-r4s-ddr3-v<版本>`）
- 每周日 02:00（UTC）自动检查 X-WRT 最新标签和 dae 最新版本；若对应版本已发布则自动跳过，不重复编译

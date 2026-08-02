# X-WRT for NanoPi R4S DDR3 1GB

让 NanoPi R4S 1G DDR3 版也能运行 X-WRT 的固件：系统保持官方 X-WRT 不变，引导区替换为 immortalwrt 的 U-Boot。

## 固件特点

- 官方不支持的 **1G DDR3 版可正常启动**，4G LPDDR4 版同样可用（U-Boot 自动识别内存）
- 系统与官方 X-WRT 完全一致：LuCI 界面、软件包、默认地址 `192.168.15.1`
- 引导区使用 rkbin DDR 初始化，自动检测 DDR3/LPDDR3/LPDDR4
- sysupgrade 升级不会覆盖引导区，1G 兼容性可长期保持
- 同时发布 squashfs 和 ext4 两种格式，均为 `.img.gz` + `.sha256`

## 下载与刷写

固件发布在 [Releases](https://github.com/ChunY1n/r4sxwrt/releases)，下载 `.img.gz` 后用 balenaEtcher 或 dd 刷入 SD 卡即可。

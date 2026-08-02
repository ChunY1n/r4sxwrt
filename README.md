# X-WRT for NanoPi R4S DDR3 1GB

让 NanoPi R4S **DDR3 1GB 版**也能运行 X-WRT 的固件编译方案：系统保持官方 X-WRT 不变，引导区替换为 immortalwrt 的 U-Boot（rkbin DDR 初始化支持 DDR3/LPDDR3/LPDDR4 自动检测）。

## 背景

NanoPi R4S 有两个版本：

- LPDDR4 版本（4GB/2GB）— X-WRT 官方支持
- DDR3 版本（1GB）— X-WRT 官方不支持

X-WRT 不支持 DDR3 版的原因：X-WRT 使用 pine64-img 引导流程，其 U-Boot（主线 U-Boot 的 nanopi-r4s-rk3399 配置，`CONFIG_RAM_ROCKCHIP_LPDDR4=y`）只编译了 LPDDR4 的 DDR 训练代码。在 1GB DDR3 板上，TPL 阶段执行 LPDDR4 初始化失败，机器无法启动。

## 方案原理

用 immortalwrt 的引导区替换 X-WRT 固件中的引导区。immortalwrt 使用 Rockchip rkbin 的 `rk3399_ddr_800MHz_v1.30.bin` 做 DDR 初始化（自动检测 DDR3/LPDDR3/LPDDR4），随后由 miniloader 加载 U-Boot 主体（U-Boot 主体不再重新初始化 DDR），因此 1GB DDR3 版能正常启动。

项目 | X-WRT（原始） | immortalwrt | 本方案
---|---|---|---
引导流程 | pine64-img（单个 u-boot-rockchip.bin @ sector 64） | pine64-bin（idbloader + uboot.img + trust.bin） | 替换引导区
DDR 初始化 | U-Boot 内置 TPL，仅 LPDDR4 训练代码 | rk3399_ddr_800MHz_v1.30.bin（自动检测） | 同 immortalwrt
分区表 | MBR，第一个分区 @ sector 65536 (32MB) | MBR，第一个分区 @ sector 65536 (32MB) | 保持 X-WRT 原样
文件系统 | X-WRT | immortalwrt | 保持 X-WRT 原样

### 引导区域布局（sector 64-32767，共 16MB）

Sector | X-WRT 原始 | 替换后（immortalwrt）
---|---|---
64-16383 | u-boot-rockchip.bin（TPL + SPL） | idbloader（DDR 初始化 + miniloader）
16384-24575 | u-boot-rockchip.bin 内含的 u-boot.itb | uboot.img（U-Boot 主体）
24576-32767 | （空） | trust.bin（ATF）

两个镜像的分区表都是 MBR（不是 GPT），bootloader 保留区都是 sector 64-32767，第一个分区从 sector 65536 (32MB) 开始。替换只写引导区，不触碰分区表和文件系统。

## 固件产物

每次编译会同时产出两种格式（与官方发布习惯一致），发布在 [Releases](https://github.com/ChunY1n/r4sxwrt/releases) 页面：

| 文件 | 说明 |
|---|---|
| `xwrt-r4s-ddr3-squashfs-<版本>.img.gz` | squashfs 版刷机包（默认推荐） |
| `xwrt-r4s-ddr3-squashfs-<版本>.sha256` | 对应校验值 |
| `xwrt-r4s-ddr3-ext4-<版本>.img.gz` | ext4 版刷机包 |
| `xwrt-r4s-ddr3-ext4-<版本>.sha256` | 对应校验值 |
| `README.txt` | 简单说明（纯英文，避免编码乱码） |

只发布压缩包和校验值，不发布未压缩的 `.img`。

## 使用方法

### 1. 编译

在仓库 Actions 页面选择 **Build X-WRT R4S DDR3** 工作流，运行参数：

- `xwrt_tag`：X-WRT 分支/标签，默认 `v26.04_b202604250947`（稳定分支），`master` 为 26.04 开发版
- `immwrt_tag`：immortalwrt 版本，默认 `25.12.1`，或 `snapshot`

> 注意：`xwrt_tag` 必须是 x-wrt/x-wrt 仓库真实存在的分支或标签；官方下载站的构建版本号不是 git 标签，不能直接填。

编译约 1-2 小时，完成后产物会出现在 Actions 的 Artifacts 中，并由人工同步发布到 Releases。

### 2. 刷写

```bash
# 校验
sha256sum -c xwrt-r4s-ddr3-squashfs-<版本>.sha256

# 方法一：balenaEtcher 直接刷写 .img.gz
# 方法二：dd
gunzip -c xwrt-r4s-ddr3-squashfs-<版本>.img.gz | sudo dd of=/dev/sdX bs=4M conv=fsync
```

刷入 SD 卡后插到 R4S 1GB 版上电，LuCI 默认地址 `192.168.15.1`。

## 文件说明

```
.github/workflows/
└── build-r4s-ddr3.yml    # GitHub Actions 工作流
build.sh                   # X-WRT 构建脚本（从 build-release 改编）
upload.sh                  # 上传脚本（空壳，实际由 Actions 处理）
replace-uboot.sh           # U-Boot 替换脚本（CI 和手动操作均使用）
README.md                  # 本文件
```

`replace-uboot.sh` 会先校验两个镜像的分区布局和 immortalwrt 引导区魔数（`LOADER` / `BL3X`），替换后再校验一次，避免在镜像布局变化时产出坏固件。

## 技术细节

- **boot.scr 兼容**：X-WRT 的 boot.scr 为未压缩（`-C none`），immortalwrt 的为 LZMA（`-C lzma`），mkimage 格式自描述，immortalwrt 的 U-Boot 能直接读取。
- **内存大小**：R4S 内核设备树没有 memory 节点，内存由 U-Boot 检测后写入 DTB，1GB 版自动识别为 1GB。
- **编译流程**：与 x-wrt/build-release 相同（feeds update/install + `TARGET=rockchip-armv8 sh build.sh`），工作流会把设备列表裁剪为只保留 NanoPi R4S，缩短构建时间。
- **手动替换**：`./replace-uboot.sh <xwrt-image> <immortalwrt-image> [output-image]`，默认输出 `xxx-ddr3.img`，不修改原文件。

## 注意事项

- sysupgrade 升级不会覆盖 U-Boot，1G 兼容性可以保持；
- 如果刷写 X-WRT 官方原版镜像，引导区会恢复为仅支持 LPDDR4 的 U-Boot。

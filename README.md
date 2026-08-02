# X-WRT for NanoPi R4S DDR3 1GB 编译方案

## 背景

NanoPi R4S 有两个版本：

- LPDDR4 版本（4GB/2GB）— X-WRT 官方支持
- DDR3 版本（1GB）— X-WRT 官方不支持

X-WRT 不支持 DDR3 版本的原因：X-WRT 使用 pine64-img 引导流程，其 U-Boot（主线 U-Boot 的 nanopi-r4s-rk3399 配置，`CONFIG_RAM_ROCKCHIP_LPDDR4=y`）只编译了 LPDDR4 的 DDR 训练代码。在 1GB DDR3 板上，TPL 阶段执行 LPDDR4 初始化失败，串口会输出 `sdram_init: LPDDR4 - 50MHz failed!`，机器无法启动。

## 方案原理

用 immortalwrt 的引导区替换 X-WRT 固件中的引导区。immortalwrt 使用 Rockchip rkbin 的 `rk3399_ddr_800MHz_v1.30.bin` 做 DDR 初始化，该二进制会自动检测 DDR3/LPDDR3/LPDDR4；随后由 miniloader 加载 U-Boot 主体（U-Boot 主体不再重新初始化 DDR），因此 1GB DDR3 版也能正常启动。

项目 | X-WRT（原始） | immortalwrt | 本方案
---|---|---|---
引导流程 | pine64-img（单个 u-boot-rockchip.bin @ sector 64） | pine64-bin（idbloader + uboot.img + trust.bin） | 替换引导区
DDR 初始化 | U-Boot 内置 TPL，仅 LPDDR4 训练代码 | rk3399_ddr_800MHz_v1.30.bin（自动检测 DDR3/LPDDR3/LPDDR4） | 同 immortalwrt
分区表 | MBR，第一个分区 @ sector 65536 (32MB) | MBR，第一个分区 @ sector 65536 (32MB) | 保持 X-WRT 原样
文件系统 | X-WRT | immortalwrt | 保持 X-WRT 原样

### 引导区域布局（sector 64-32767，共 16MB）

Sector | X-WRT 原始 | 替换后（immortalwrt）
---|---|---
64-16383 | u-boot-rockchip.bin（TPL + SPL） | idbloader（DDR 初始化 + miniloader）
16384-24575 | u-boot-rockchip.bin 内含的 u-boot.itb（FIT） | uboot.img（U-Boot 主体）
24576-32767 | （空） | trust.bin（ATF）

> 注：X-WRT 的单个 u-boot-rockchip.bin 实际一直延伸到约 sector 18593（sector 16384 起是它内部包含的 u-boot.itb）。替换时直接覆盖即可。

### 为什么替换是安全的

- 两个镜像的分区表都是 MBR（不是 GPT），bootloader 保留区都是 sector 64-32767；
- 第一个分区（ext4，存放 kernel.img 和 boot.scr）从 sector 65536 (32MB) 开始；
- 替换只写 sector 64-32767，不触碰分区表和文件系统。

### DDR 初始化二进制

rk3399_ddr_800MHz_v1.30.bin 来自 Rockchip rkbin 仓库，支持 DDR3 / LPDDR3 / LPDDR4，自动检测内存类型，无需手动配置。

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

## 使用方法

### 1. Fork 或导入到 GitHub

将整个仓库推送到 GitHub。

### 2. 运行 GitHub Actions

在 GitHub 仓库页面：

- 进入 Actions 标签
- 选择 Build X-WRT R4S DDR3 工作流
- 点击 Run workflow
- 输入参数：
  - `xwrt_tag`: `master`（最新 26.04 开发版）或稳定分支如 `v26.04_b202604250947`
  - `immwrt_tag`: `25.12.1`（最新稳定版）或 `snapshot`（每日最新）

> 注意：`xwrt_tag` 必须是 x-wrt/x-wrt 仓库真实存在的分支或标签（稳定分支形如 `v26.04_b202604250947`）。官方下载站的构建版本号（如 `26.04-b202607300654`）不是 git 标签，不能直接填。

### 3. 下载固件

编译完成后（约 1-2 小时），从 Actions 的 Artifacts 下载固件。

### 4. 刷写固件

```bash
# 方法一：使用 dd
gunzip xwrt-r4s-ddr3-*.img.gz
sudo dd if=xwrt-r4s-ddr3-*.img of=/dev/sdX bs=4M conv=fsync

# 方法二：使用 balenaEtcher
# 直接刷写 .img.gz 文件
```

## 默认版本

参数 | 默认值 | 说明
---|---|---
xwrt_tag | v26.04_b202604250947 | X-WRT 最新稳定分支（master 为 26.04 开发版）
immwrt_tag | 25.12.1 | immortalwrt 最新稳定版

## 技术细节

### boot.scr 兼容性

- X-WRT 的 boot.scr 使用 `-C none`（未压缩）
- immortalwrt 的 boot.scr 使用 `-C lzma`（LZMA 压缩）
- immortalwrt 的 U-Boot 能读取未压缩的 boot.scr，兼容无问题

### 内核内存大小

R4S 的内核设备树没有 memory 节点，内存大小由 U-Boot 检测后写入 DTB。immortalwrt 的 U-Boot 在 1GB 板上检测为 1GB，内核正常识别。

### X-WRT 编译流程

使用与 x-wrt/build-release 相同的流程：

```bash
./scripts/feeds update -a
./scripts/feeds install -a
TARGET=rockchip-armv8 sh build.sh $(nproc)
```

build.sh 会：

- 从 `cfg.list` 读取 `config.rockchip-armv8` 配置
- 设置 `WORKFLOW=1` 环境变量
- 创建 `.build_x/env` 版本文件
- 调用 `feeds/x/rom/lede/make.sh make -j$(nproc)`

工作流会在编译前把设备列表裁剪为只保留 NanoPi R4S，缩短编译时间和磁盘占用。

### 手动替换命令

```bash
./replace-uboot.sh <xwrt-image> <immortalwrt-image> [output-image]
```

脚本会生成 `xxx-ddr3.img`（默认输出名），不会修改原文件。

## 参考链接

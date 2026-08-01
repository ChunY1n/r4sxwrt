# X-WRT for NanoPi R4S DDR3 1GB 编译方案

## 背景

NanoPi R4S 有两个版本：
- **LPDDR4 版本**（4GB/2GB）— X-WRT 官方支持
- **DDR3 版本**（1GB）— X-WRT 官方不支持

X-WRT 不支持 DDR3 版本的原因：使用 `pine64-img` 引导流程，其 U-Boot 内置 LPDDR4 专用 DDR 初始化代码。

## 方案原理

通过替换 X-WRT 固件的引导区域，使用 immortalwrt 的 DDR3 兼容 U-Boot：

| 项目 | X-WRT（原始） | immortalwrt | 本方案 |
|------|-------------|------------|--------|
| 引导流程 | `pine64-img` | `pine64-bin` | 替换引导区域 |
| DDR 初始化 | LPDDR4 专用 | rk3399_ddr_800MHz_v1.30.bin（自动检测 DDR3/LPDDR3/LPDDR4） | 同 immortalwrt |
| 引导文件 | 单个 u-boot-rockchip.bin @ sector 64 | idbloader + uboot.img + trust.bin | 同 immortalwrt |
| 分区表 | sector 32768+ | sector 32768+ | 保持 X-WRT 原样 |
| 文件系统 | X-WRT | immortalwrt | 保持 X-WRT 原样 |

### 引导区域布局（sector 64-32767，共 16MB）

| Sector | X-WRT 原始 | 替换后（immortalwrt） |
|--------|-----------|---------------------|
| 64-16383 | u-boot-rockchip.bin | idbloader（DDR 初始化 + miniloader） |
| 16384-24575 | （空） | uboot.img（U-Boot 主体） |
| 24576-32767 | （空） | trust.bin（ATF） |

### DDR 初始化二进制

`rk3399_ddr_800MHz_v1.30.bin` 来自 Rockchip rkbin 仓库，支持：
- DDR3
- LPDDR3
- LPDDR4

自动检测内存类型，无需手动配置。

## 文件说明

```
xwrt-r4s-ddr3-ci/
├── .github/workflows/
│   └── build-r4s-ddr3.yml    # GitHub Actions 工作流
├── build.sh                   # X-WRT 构建脚本（从 build-release 改编）
├── upload.sh                  # 上传脚本（空壳，实际由 Actions 处理）
├── replace-uboot.sh           # 独立 U-Boot 替换脚本（手动操作用）
└── README.md                  # 本文件
```

## 使用方法

### 1. Fork 或导入到 GitHub

将整个 `xwrt-r4s-ddr3-ci` 目录推送到 GitHub 仓库。

### 2. 运行 GitHub Actions

在 GitHub 仓库页面：
1. 进入 **Actions** 标签
2. 选择 **Build X-WRT R4S DDR3** 工作流
3. 点击 **Run workflow**
4. 输入参数：
   - `xwrt_tag`: `master`（最新 26.04 开发版）或具体标签如 `26.04_b202606240712`
   - `immwrt_tag`: `25.12.1`（最新稳定版）或 `snapshot`（每日最新）

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

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `xwrt_tag` | `master` | X-WRT 最新 26.04 开发版 |
| `immwrt_tag` | `25.12.1` | immortalwrt 最新稳定版（2026-07-07 发布） |

## 技术细节

### boot.scr 兼容性

- X-WRT 的 boot.scr 使用 `-C none`（未压缩）
- immortalwrt 的 boot.scr 使用 `-C lzma`（LZMA 压缩）
- immortalwrt 的 U-Boot 能读取未压缩的 boot.scr，兼容无问题

### X-WRT 编译流程

使用与 [x-wrt/build-release](https://github.com/x-wrt/build-release) 相同的流程：

1. `./scripts/feeds update -a` — 更新 feeds
2. `./scripts/feeds install -a` — 安装 feeds
3. `TARGET=rockchip-armv8 sh build.sh $(nproc)` — 编译

`build.sh` 会：
- 从 `cfg.list` 读取 `config.rockchip-armv8` 配置
- 设置 `WORKFLOW=1` 环境变量
- 创建 `.build_x/env` 版本文件
- 调用 `feeds/x/rom/lede/make.sh make -j$(nproc)`

### 替换命令

```bash
# 从 immortalwrt 提取引导区域
dd if=immwrt-r4s.img of=uboot-boot-area.bin bs=512 skip=64 count=32704

# 写入 X-WRT 固件
dd if=uboot-boot-area.bin of=xwrt-r4s.img seek=64 conv=notrunc
```

## 参考链接

- X-WRT 源码: https://github.com/x-wrt/x-wrt
- X-WRT 固件下载: https://downloads.x-wrt.com/rom/
- X-WRT build-release: https://github.com/x-wrt/build-release
- immortalwrt 源码: https://github.com/immortalwrt/immortalwrt
- immortalwrt 固件下载: https://downloads.immortalwrt.org
- Rockchip rkbin: https://github.com/rockchip-linux/rkbin
- Rockchip 启动流程: http://opensource.rock-chips.com/wiki_Boot_option

#!/bin/bash
# replace-uboot.sh
# 将 immortalwrt 的 U-Boot 引导区域替换到 X-WRT 固件中
# 两者都在 sector 64-32767 (16MB) 保留引导区域，布局兼容

set -e

XWRT_IMG="$1"
IMMWRT_IMG="$2"

if [ -z "$XWRT_IMG" ] || [ -z "$IMMWRT_IMG" ]; then
    echo "Usage: $0 <xwrt-image> <immortalwrt-image>"
    echo ""
    echo "Example:"
    echo "  $0 x-wrt-*-friendlyarm_nanopi-r4s-squashfs-sysupgrade.img immortalwrt-*-friendlyarm_nanopi-r4s-squashfs-sysupgrade.img"
    exit 1
fi

echo "=== 替换 U-Boot 引导区域 ==="
echo "X-WRT 固件: $XWRT_IMG"
echo "immortalwrt 固件: $IMMWRT_IMG"

# 扇区 64 = 偏移 0x8000 (32768 bytes)
# 扇区 32768 = 偏移 0x4000000 (16777216 bytes = 16MB)
# 引导区域大小 = 32768 - 64 = 32704 扇区 = 16773120 bytes
SEEK_SECTORS=64
COUNT_SECTORS=32704
BS=512

echo ""
echo "从 immortalwrt 镜像提取引导区域 (sector 64-32767, ~16MB)..."
dd if="$IMMWRT_IMG" of=uboot-boot-area.bin bs=$BS skip=$SEEK_SECTORS count=$COUNT_SECTORS status=progress

echo ""
echo "将引导区域写入 X-WRT 镜像 (sector 64)..."
dd if=uboot-boot-area.bin of="$XWRT_IMG" seek=$SEEK_SECTORS conv=notrunc status=progress

echo ""
echo "=== U-Boot 替换完成 ==="
echo "修改后的固件: $XWRT_IMG"
echo ""
echo "现在可以使用 balenaEtcher 或 dd 将固件刷入 SD 卡"

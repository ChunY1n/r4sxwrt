#!/bin/bash
# replace-uboot.sh
# 将 immortalwrt 的 U-Boot 引导区（idbloader + uboot.img + trust.bin）替换到 X-WRT 固件，
# 使 X-WRT 支持 NanoPi R4S DDR3 1GB 版。
#
# 布局说明：
#   - 两个镜像都是 MBR 分区表，第一个分区从 sector 65536 (32MB) 开始；
#   - sector 64-32767 (16MB) 是引导保留区，替换它不影响分区表和文件系统。
#
# 用法: $0 <xwrt-image> <immortalwrt-image> [output-image]

set -e

XWRT_IMG="$1"
IMMWRT_IMG="$2"
OUT_IMG="${3:-${XWRT_IMG%.img}-ddr3.img}"

if [ -z "$XWRT_IMG" ] || [ -z "$IMMWRT_IMG" ]; then
    echo "用法: $0 <xwrt-image> <immortalwrt-image> [output-image]"
    echo ""
    echo "示例:"
    echo "  $0 x-wrt-26.04-*-friendlyarm_nanopi-r4s-squashfs-sysupgrade.img \\"
    echo "     immortalwrt-25.12.1-rockchip-armv8-friendlyarm_nanopi-r4s-squashfs-sysupgrade.img"
    exit 1
fi

BS=512
BOOT_START=64
BOOT_COUNT=$((32768 - BOOT_START))   # 32704 sectors = 16MB 引导区
FIRST_PART=65536                     # 第一个分区起始 sector (32MB)

echo "=== 替换 U-Boot 引导区 ==="
echo "X-WRT 固件:       $XWRT_IMG"
echo "immortalwrt 固件: $IMMWRT_IMG"
echo "输出固件:         $OUT_IMG"
echo ""

for f in "$XWRT_IMG" "$IMMWRT_IMG"; do
    [ -f "$f" ] || { echo "错误: 文件不存在: $f"; exit 1; }
done

# 读取 MBR 中第一个分区起始 LBA（偏移 454, 小端 u32）
mbr_part1() {
    dd if="$1" bs=1 skip=454 count=4 2>/dev/null | od -An -tx1 | tr -d ' \n'
}

check_mbr() {
    local f="$1"
    local sig
    sig=$(dd if="$f" bs=1 skip=510 count=2 2>/dev/null | od -An -tx1 | tr -d ' \n')
    [ "$sig" = "55aa" ] || { echo "错误: $f 不是有效的 MBR 镜像"; exit 1; }
    [ "$(mbr_part1 "$f")" = "00000100" ] || {
        echo "错误: $f 第一个分区不在 sector $FIRST_PART (32MB)，布局与预期不符"; exit 1; }
}

check_magic() { # <file> <sector> <expected>
    local got
    got=$(dd if="$1" bs=$BS skip="$2" count=1 2>/dev/null | head -c "${#3}")
    [ "$got" = "$3" ] || { echo "错误: $1 的 sector $2 魔数不是 '$3' (实际: '$got')"; exit 1; }
}

check_mbr "$XWRT_IMG"
check_mbr "$IMMWRT_IMG"

# X-WRT 原始引导区: sector 64 应有 u-boot-rockchip.bin 数据
if [ -z "$(dd if="$XWRT_IMG" bs=$BS skip=64 count=1 2>/dev/null | od -An -tx1 | tr -d ' 0\n')" ]; then
    echo "错误: X-WRT 镜像 sector 64 没有引导数据"; exit 1
fi

# immortalwrt pine64-bin 布局: uboot.img @16384, trust.bin @24576
check_magic "$IMMWRT_IMG" 16384 "LOADER  "
check_magic "$IMMWRT_IMG" 24576 "BL3X"

# 复制原始 X-WRT 镜像，避免破坏原文件
cp -f "$XWRT_IMG" "$OUT_IMG"

echo ""
echo "从 immortalwrt 提取引导区 (sector $BOOT_START-$((BOOT_START + BOOT_COUNT - 1))) 并写入 $OUT_IMG ..."
dd if="$IMMWRT_IMG" of="$OUT_IMG" bs=$BS skip=$BOOT_START seek=$BOOT_START \
   count=$BOOT_COUNT conv=notrunc status=progress

# 替换后校验
check_magic "$OUT_IMG" 16384 "LOADER  "
check_magic "$OUT_IMG" 24576 "BL3X"
cmp -n $((BOOT_START * BS)) "$XWRT_IMG" "$OUT_IMG" || {
    echo "错误: 替换后前 $BOOT_START 个 sector 与原始 X-WRT 镜像不一致（分区表被改动）"; exit 1; }

echo ""
echo "=== U-Boot 替换完成 ==="
echo "输出固件: $OUT_IMG"
echo "提示: 首次刷写请使用该完整镜像；之后在 X-WRT 内 sysupgrade 不会覆盖引导区。"

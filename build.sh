#!/bin/bash
# build.sh — 从 x-wrt/build-release 改编
# 用于 GitHub Actions 编译 X-WRT rockchip-armv8 目标

TARGET=${TARGET-x86_64}

CFGS=`cat ./feeds/x/rom/lede/cfg.list | grep "config.$TARGET$"`

export CFGS="`echo $CFGS`"
export WORKFLOW="1"

echo "=== Build Configuration ==="
echo "TARGET: $TARGET"
echo "CFGS: $CFGS"
echo "WORKFLOW: $WORKFLOW"
echo "Version: $(cat release.tag)"
echo "CPUs: $(nproc)"
echo "==========================="

df -h .
free -m
echo "Starting build in 10s..."
sleep 10

mkdir -p .build_x
echo CONFIG_VERSION_NUMBER=\"`cat release.tag`\" >.build_x/env

echo "Running make.sh..."
./feeds/x/rom/lede/make.sh make -j$1
_EXIT=$?

if [ "x$_EXIT" = "x0" ]; then
    echo "Build succeeded!"
    # 列出编译产物
    echo "=== Build Output ==="
    find bin/targets/ -name "*.img*" -o -name "*.bin*" 2>/dev/null | while read f; do
        ls -lh "$f"
    done
    echo "===================="
else
    echo "首次编译失败（退出码 $_EXIT），用 V=s 完整重试..."
    if make V=s >/tmp/xwrt-retry.log 2>&1; then
        echo "V=s 重试成功，继续后续流程"
        tail -300 /tmp/xwrt-retry.log
        exit 0
    else
        echo "V=s 重试仍失败"
        tail -300 /tmp/xwrt-retry.log
        exit $_EXIT
    fi
fi

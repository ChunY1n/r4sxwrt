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
    echo "Build failed with exit code $_EXIT, retrying with V=s for error details..."
    make V=s 2>&1 | tail -300
    exit $_EXIT
fi

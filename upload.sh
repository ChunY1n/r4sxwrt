#!/bin/bash
# upload.sh — 空壳脚本，编译成功后列出产物
# 实际上传由 GitHub Actions upload-artifact 处理

echo "=== Upload (skip) ==="
find bin/targets/ -name "*.img*" -o -name "*.bin*" 2>/dev/null | while read f; do
    echo "  $f ($(du -h "$f" | cut -f1))"
done
echo "======================"

exit 0

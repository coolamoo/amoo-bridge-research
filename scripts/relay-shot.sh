#!/usr/bin/env bash
# 设备侧：把最新一张截图后台传到 ntfy
# 用法: ./relay-shot.sh <topic>
set -euo pipefail

TOPIC="${1:?需要 topic，例如 stepx_shot}"
HOST="${NTFY_HOST:-https://ntfy.mzte.de}"

f=$(ls -t /sdcard/StepBridge/out/shot_*.jpg 2>/dev/null | head -1)
[ -n "$f" ] || { echo "没有找到截图，先发一条 {\"op\":\"shot\"}" >&2; exit 1; }

echo "$f"
nohup curl -s -T "$f" -H "Filename: shot.jpg" "$HOST/$TOPIC" >/dev/null 2>&1 &
echo "已后台上传到 $HOST/$TOPIC"

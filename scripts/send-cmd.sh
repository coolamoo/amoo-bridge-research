#!/usr/bin/env bash
# 往桥的命令队列塞一条命令，并等待结果
# 用法: ./send-cmd.sh '{"op":"ping"}'
set -euo pipefail

IN=/sdcard/StepBridge/in
OUT=/sdcard/StepBridge/out
BODY="${1:?需要命令 JSON}"
ID="cmd-$(date +%s%3N)"

mkdir -p "$IN" "$OUT"
printf '%s' "$BODY" > "$IN/$ID.cmd"

for _ in $(seq 1 40); do
  [ -f "$OUT/$ID.res" ] && { cat "$OUT/$ID.res"; exit 0; }
  sleep 0.25
done

echo "超时：桥可能已经停止（in/ 有 cmd、out/ 无 res）" >&2
exit 1

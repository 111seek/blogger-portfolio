#!/usr/bin/env bash
# 一条命令走完「构建 → 起服务 → 手机能看 → 改完自动重建」的循环
#
#   bash scripts/preview.sh                      # 预览 demo/data.json，自动开浏览器
#   bash scripts/preview.sh my-portfolio/data.json
#   bash scripts/preview.sh --port 9000 --no-watch
#   bash scripts/preview.sh --demo-banner        # 带「示例页面」角标，等同线上 demo
#
# 逻辑：
#   1. 构建到 .preview/index.html（已被 .gitignore 忽略，不会误提交）
#   2. 在该目录起 python3 -m http.server，绑定 0.0.0.0，手机同 Wi-Fi 可访问
#   3. 盯着 data.json / 模板 / 封面图，一变就重建 —— 手机下拉刷新即可，不用重启
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DATA="demo/data.json"
PORT=8080
OUT_DIR=".preview"
WATCH=1
OPEN=1
BANNER=()

while [ $# -gt 0 ]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    --no-watch) WATCH=0; shift ;;
    --no-open) OPEN=0; shift ;;
    --demo-banner) BANNER=(--demo-banner); shift ;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) DATA="$1"; shift ;;
  esac
done

cd "$SKILL_DIR" || exit 1

command -v python3 >/dev/null 2>&1 || { echo "✗ 需要 python3" >&2; exit 1; }
[ -f "$DATA" ] || { echo "✗ 找不到数据文件：$DATA" >&2; exit 1; }

OUT_DIR="${OUT_DIR#/}"
mkdir -p "$OUT_DIR"

# macOS: md5 -q；Linux: md5sum
if command -v md5 >/dev/null 2>&1; then HASH() { md5 -q "$@"; }; else HASH() { md5sum "$@" | cut -d' ' -f1; }; fi

# data.json 所在目录下的图片改动也要盯上（封面/头像）
INPUTS=("$DATA" "assets/template.html")
for ext in webp jpg jpeg png svg; do
  for f in "$(dirname "$DATA")"/assets/*."$ext"; do
    [ -f "$f" ] && INPUTS+=("$f")
  done
done

stamp() { HASH "${INPUTS[@]}" 2>/dev/null | tr -d '\n'; }

build() {
  local t0 t1
  t0=$(date +%s)
  if out=$(python3 scripts/build.py --data "$DATA" --out "$OUT_DIR/index.html" ${BANNER[@]+"${BANNER[@]}"} 2>&1); then
    t1=$(date +%s)
    printf '\033[32m✓\033[0m %s 秒构建完成 · %s\n' "$((t1 - t0))" "$(printf '%s' "$out" | head -1 | sed 's/^✓ 已生成 //')"
  else
    printf '\033[31m✗\033[0m 构建失败：\n%s\n' "$out"
  fi
}

lan_ip() {
  if command -v ipconfig >/dev/null 2>&1; then
    for i in en0 en1 en2; do
      ip=$(ipconfig getifaddr "$i" 2>/dev/null) && [ -n "$ip" ] && { echo "$ip"; return; }
    done
  fi
  hostname -I 2>/dev/null | awk '{print $1}'
}

echo "数据源：$DATA"
build

echo
printf '  本地：\033[1mhttp://127.0.0.1:%s\033[0m\n' "$PORT"
IP=$(lan_ip)
if [ -n "${IP:-}" ]; then
  printf '  手机：\033[1mhttp://%s:%s\033[0m   ← 同一 Wi-Fi 下打开\n' "$IP" "$PORT"
else
  printf '  ！没取到内网 IP，手机可能访问不了（检查是否连了 Wi-Fi）\n'
fi
[ "$WATCH" = "1" ] && printf '  改动 data.json / 模板 / 封面后自动重建，手机下拉刷新即可。Ctrl+C 退出。\n'
echo

if [ "$OPEN" = "1" ]; then
  if command -v open >/dev/null 2>&1; then open "http://127.0.0.1:${PORT}" >/dev/null 2>&1
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "http://127.0.0.1:${PORT}" >/dev/null 2>&1
  fi
fi

python3 -m http.server "$PORT" --bind 0.0.0.0 --directory "$OUT_DIR" >/dev/null 2>&1 &
SRV=$!
cleanup() { kill "$SRV" 2>/dev/null; printf '\n已停止预览服务。\n'; exit 0; }
trap cleanup INT TERM

if [ "$WATCH" = "1" ]; then
  LAST=$(stamp)
  while kill -0 "$SRV" 2>/dev/null; do
    sleep 1
    NOW=$(stamp)
    if [ "$NOW" != "$LAST" ]; then
      LAST="$NOW"
      printf '\n[%s] 检测到改动，重建中…\n' "$(date +%H:%M:%S)"
      build
    fi
  done
else
  wait "$SRV"
fi

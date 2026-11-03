#!/usr/bin/env bash
# redbook CLI 启动器 —— 让 skill 自带 CLI，不依赖对方先 npm i -g
#
# 解析顺序：
#   1. $REDBOOK_BIN            显式指定，用于特殊环境
#   2. command -v redbook      全局安装版（会自动跟随 npm 升级，优先）
#   3. vendor/redbook/dist/cli.js  技能内置副本（离线可用，无需任何安装）
#
# 用法与原生 redbook 完全一致：
#   bash scripts/redbook.sh whoami
#   bash scripts/redbook.sh user-posts <userId> --all --delay 3000 --json > posts.json
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 凭据默认位置（原生 CLI 也认这个变量）
export REDBOOK_COOKIE_FILE="${REDBOOK_COOKIE_FILE:-$HOME/.redbook/cookies.json}"

if [ -n "${REDBOOK_BIN:-}" ]; then
  exec "$REDBOOK_BIN" "$@"
fi

if command -v redbook >/dev/null 2>&1; then
  exec redbook "$@"
fi

VENDOR_CLI="$SKILL_DIR/vendor/redbook/dist/cli.js"
if [ -f "$VENDOR_CLI" ]; then
  command -v node >/dev/null 2>&1 || {
    echo "redbook: 内置副本需要 node（>=22），当前找不到 node。" >&2
    exit 127
  }
  exec node "$VENDOR_CLI" "$@"
fi

cat >&2 <<'EOF'
redbook: 找不到 CLI。
  · 全局未安装 redbook
  · 技能内置副本 vendor/redbook/dist/cli.js 也不存在（可能分享时漏拷了 vendor/）

补救（任选其一）：
  npm i -g @lucasygu/redbook        # 装全局版
  重新拷一份完整 skill 目录（含 vendor/）
EOF
exit 127

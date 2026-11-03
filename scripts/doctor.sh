#!/usr/bin/env bash
# 前置体检 —— 取数之前先跑这个，把"环境问题"和"数据问题"分开
#
#   bash scripts/doctor.sh            # 完整体检（含登录态验证，需要联网）
#   bash scripts/doctor.sh --offline  # 只查本地：node / CLI / cookie 文件
#
# 退出码：0 = 可以取数；1 = 有阻塞项
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COOKIE="${REDBOOK_COOKIE_FILE:-$HOME/.redbook/cookies.json}"
OFFLINE=0
[ "${1:-}" = "--offline" ] && OFFLINE=1

FAIL=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }

echo "1) Node"
if command -v node >/dev/null 2>&1; then
  NODE_V="$(node -v)"
  NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
  if [ "$NODE_MAJOR" -ge 22 ] 2>/dev/null; then
    ok "node $NODE_V"
  else
    bad "node $NODE_V 版本过低，redbook 要求 >=22"
  fi
else
  bad "找不到 node（redbook 运行时依赖 node >=22）"
fi

echo "2) CLI"
if [ -n "${REDBOOK_BIN:-}" ] && [ -x "${REDBOOK_BIN}" ]; then
  ok "REDBOOK_BIN=$REDBOOK_BIN"
  CLI_MODE="env"
elif command -v redbook >/dev/null 2>&1; then
  ok "全局命令 $(command -v redbook) · 版本 $(redbook --version 2>/dev/null || echo '?')"
  CLI_MODE="global"
elif [ -f "$SKILL_DIR/vendor/redbook/dist/cli.js" ]; then
  if command -v node >/dev/null 2>&1; then
    ok "技能内置副本 vendor/redbook · 版本 $(node "$SKILL_DIR/vendor/redbook/dist/cli.js" --version 2>/dev/null || echo '?')（未装全局，直接用内置）"
  else
    bad "有内置副本但找不到 node，跑不起来 → 先装 node >=22"
  fi
  CLI_MODE="vendor"
else
  bad "既没有全局 redbook，也没有 vendor/redbook（skill 目录可能拷漏了）→ npm i -g @lucasygu/redbook"
  CLI_MODE="none"
fi
[ "$CLI_MODE" = "global" ] && warn "用的是全局版；若报 command not found 的怪错，可设 REDBOOK_BIN 或删掉全局版改走内置副本"

echo "3) 凭据"
if [ -f "$COOKIE" ]; then
  PERM="$(stat -f '%OLp' "$COOKIE" 2>/dev/null || stat -c '%a' "$COOKIE" 2>/dev/null)"
  AGE_D=$(( ( $(date +%s) - $(stat -f '%m' "$COOKIE" 2>/dev/null || stat -c '%Y' "$COOKIE") ) / 86400 ))
  ok "${COOKIE}（权限 ${PERM}，${AGE_D} 天前写入）"
  [ "$PERM" != "600" ] && warn "权限不是 600，建议 chmod 600 \"$COOKIE\""
  [ "$AGE_D" -gt 30 ] && warn "凭据已 $AGE_D 天，小红书 session 通常 30–40 天过期，失效就重新 auth save"
else
  bad "找不到 $COOKIE"
  cat <<'EOF'
     登录（本机 Chrome 已登录小红书）：
       bash scripts/redbook.sh auth save
     抓不到 Cookie（钥匙串被拦）时，改用 CDP 方案，见 references/data-collection.md 文末。
EOF
fi

if [ "$OFFLINE" = "1" ]; then
  echo "4) 登录态 —— 已跳过（--offline）"
else
  echo "4) 登录态"
  if [ "$CLI_MODE" = "none" ] || [ ! -f "$COOKIE" ]; then
    warn "跳过（上面有阻塞项）"
  else
    OUT="$(bash "$SKILL_DIR/scripts/redbook.sh" whoami 2>&1 | head -5)"
    if printf '%s' "$OUT" | grep -qiE 'route_gone|unauthorized|No XHS session|401|403'; then
      bad "session 已失效 → 重新登录：bash scripts/redbook.sh auth save"
      printf '     %s\n' "$OUT"
    elif [ -n "$OUT" ]; then
      ok "$(printf '%s' "$OUT" | tr '\n' ' ' | cut -c1-80)"
    else
      warn "whoami 无输出，可能网络或接口变动，先跑一条 search 试"
    fi
  fi
fi

echo
if [ "$FAIL" = "0" ]; then
  echo "结论：可以取数。"
else
  echo "结论：有阻塞项，先按上面提示修，再取数。"
fi
exit "$FAIL"

#!/usr/bin/env bash
# 身份校验 —— 唯一目的：确认「要做的这份作品集」属于「当前登录的小红书账号」。
#
#   bash scripts/check-self.sh                          # 只看当前登录的是谁
#   bash scripts/check-self.sh --data portfolio/data.json   # 校验 data.json 指向的账号 + 写入归属记录
#   bash scripts/check-self.sh 5ba7b084b9b6ed000181523a --data portfolio/data.json
#   bash scripts/check-self.sh wudishaoshuai --data portfolio/data.json   # 也可用小红书号/昵称
#
# 判定：目标账号 == 当前登录账号 才通过；否则退出码 2。
# 通过后写入两处：
#   1) <data.json 所在目录>/.owner.lock   给 build.py 复核用
#   2) data.json 的 site.account          {user_id, red_id, nickname, verified_at}
#
# 为什么要有这道闸：本技能只允许「本人用自己的号」生成作品集，
# 替第三方博主抓数、做简历不在授权范围内（涉及他人数据与肖像）。
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=""
DATA=""
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --data) DATA="$2"; shift 2 ;;
    --quiet|-q) QUIET=1; shift ;;
    -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "✗ 未知参数：$1" >&2; exit 64 ;;
    *) TARGET="$1"; shift ;;
  esac
done

say()  { [ "$QUIET" = "1" ] || printf '%s\n' "$1"; }
ok()   { [ "$QUIET" = "1" ] || printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1" >&2; }

command -v python3 >/dev/null 2>&1 || { echo "✗ 需要 python3" >&2; exit 1; }
RB="$SKILL_DIR/scripts/redbook.sh"

# ---------- 1. 登录态 ----------
ME="$(bash "$RB" whoami --json 2>/dev/null)"
if ! printf '%s' "$ME" | grep -q '"user_id"'; then
  bad "小红书登录态不可用，先登录：bash scripts/redbook.sh auth save"
  printf '%s\n' "$ME" | head -3 | sed 's/^/     /' >&2
  exit 3
fi

IDENT="$(printf '%s' "$ME" | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(d.get("user_id",""))
print(d.get("red_id",""))
print(d.get("nickname",""))
')"
ME_ID="$(printf '%s' "$IDENT" | sed -n 1p)"
ME_RED="$(printf '%s' "$IDENT" | sed -n 2p)"
ME_NICK="$(printf '%s' "$IDENT" | sed -n 3p)"

say "当前登录：${ME_NICK}（小红书号 ${ME_RED}）"
say "          user_id ${ME_ID}"

[ -n "$ME_ID" ] || { bad "whoami 没返回 user_id，接口可能变了"; exit 3; }

# ---------- 2. 定目标账号 ----------
TARGET_ID=""
TARGET_DESC=""

if [ -z "$TARGET" ]; then
  if [ -n "$DATA" ] && [ -f "$DATA" ]; then
    TARGET="$(python3 - "$DATA" <<'PY'
import json,sys,re
d=json.load(open(sys.argv[1],encoding="utf-8"))
s=d.get("site",{})
aid=(s.get("account") or {}).get("user_id","")
if not aid:
    m=re.search(r"/user/profile/([0-9a-fA-F]{24})", s.get("profile_url","") or "")
    aid=m.group(1) if m else ""
print(aid)
PY
)"
    [ -n "$TARGET" ] && TARGET_DESC="data.json 里的账号"
    if [ -z "$TARGET" ]; then
      bad "data.json 没写明这是谁的账号"
      cat >&2 <<'EOF'
  缺 site.account.user_id，profile_url 里也没有可解析的 /user/profile/<24位 id>。

  这份数据必须能自证归属，不能默认成"当前登录的人"——那样很容易把别人的数据标成自己的。
  把 site.profile_url 改成你自己的主页链接（浏览器打开自己主页，地址栏里那串）：
      https://www.xiaohongshu.com/user/profile/<你的 user_id>
  再重跑本命令，它会自动补上 site.account。
EOF
      exit 64
    fi
  fi
fi

if [ -n "$TARGET" ]; then
  case "$TARGET" in
    http://*|https://*)
      TARGET_ID="$(printf '%s' "$TARGET" | sed -nE 's#.*/user/profile/([0-9a-fA-F]{24}).*#\1#p')"
      [ -n "$TARGET_ID" ] || { bad "链接里没解析出 userId：$TARGET"; exit 64; }
      TARGET_DESC="${TARGET_DESC:-profile_url}"
      ;;
    *)
      if printf '%s' "$TARGET" | grep -qE '^[0-9a-fA-F]{24}$'; then
        TARGET_ID="$TARGET"
      elif [ "$TARGET" = "$ME_RED" ]; then
        TARGET_ID="$ME_ID"
      elif [ "$(printf '%s' "$TARGET" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$ME_NICK" | tr 'A-Z' 'a-z')" ]; then
        TARGET_ID="$ME_ID"
      else
        bad "无法确认「${TARGET}」属于当前登录账号"
        echo "  当前登录：${ME_NICK} · 小红书号 ${ME_RED} · user_id ${ME_ID}" >&2
        echo "  请用 userId、profile_url 或当前账号的小红书号/昵称；不确定就先跑：bash scripts/redbook.sh whoami" >&2
        exit 2
      fi
      TARGET_DESC="${TARGET_DESC:-命令行参数}"
      ;;
  esac
else
  TARGET_ID="$ME_ID"
  TARGET_DESC="当前登录账号（未指定其他目标）"
fi

say "目标账号：${TARGET_ID}（来源：${TARGET_DESC}）"

# ---------- 3. 比对 ----------
if [ "$TARGET_ID" != "$ME_ID" ]; then
  if [ "$TARGET_ID" = "660000000000000000000001" ]; then
    bad "data.json 还指向 demo 的虚构账号（6600…0001），不是你的号"
    echo "  把 site.profile_url 和 site.account 换成你自己的，再重跑：" >&2
    echo "    https://www.xiaohongshu.com/user/profile/${ME_ID}" >&2
    exit 2
  fi
  bad "账号不匹配，拒绝生成"
  cat >&2 <<EOF

  要做的账号：$TARGET_ID
  当前登录的：${ME_ID}（${ME_NICK} · ${ME_RED}）

  本技能只允许「用自己的账号」做作品集，不为第三方博主代做——
  抓到的是别人的笔记、照片和商业数据，替他人成稿既越权也涉及肖像与隐私。

  两条合规路径，选一：
    1) 这就是你自己的号 → 先切到该账号登录，再重跑本命令：
         bash scripts/redbook.sh auth save
    2) 不是你的号 → 停手。让对方用自己的账号跑一遍（整个技能目录可打包给他）。

EOF
  exit 2
fi

# 若 data.json 里 profile_url 指向别的账号，也要拦下（防止锁是 A、页面链到 B）
if [ -n "$DATA" ] && [ -f "$DATA" ]; then
  LINK_ID="$(python3 - "$DATA" <<'PY'
import json,sys,re
s=json.load(open(sys.argv[1],encoding="utf-8")).get("site",{})
m=re.search(r"/user/profile/([0-9a-fA-F]{24})", s.get("profile_url","") or "")
print(m.group(1) if m else "")
PY
)"
  if [ -n "$LINK_ID" ] && [ "$LINK_ID" != "$ME_ID" ]; then
    bad "data.json 的 site.profile_url 指向另一个账号（${LINK_ID}）"
    echo "  要么改成 https://www.xiaohongshu.com/user/profile/$ME_ID ，要么先确认这确实是你自己的号。" >&2
    exit 2
  fi
fi

# ---------- 4. 落盘 ----------
LOCK_DIR="."
[ -n "$DATA" ] && LOCK_DIR="$(cd "$(dirname "$DATA")" && pwd)"

python3 - "$LOCK_DIR/.owner.lock" "$ME_ID" "$ME_RED" "$ME_NICK" "$DATA" <<'PY'
import datetime, json, pathlib, sys
lock, uid, red, nick, data = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
rec = {
    "user_id": uid,
    "red_id": red,
    "nickname": nick,
    "verified_at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
    "verified_by": "scripts/check-self.sh (redbook whoami)",
}
pathlib.Path(lock).write_text(json.dumps(rec, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

if data:
    p = pathlib.Path(data)
    d = json.loads(p.read_text(encoding="utf-8"))
    d.setdefault("site", {})["account"] = {
        "user_id": uid, "red_id": red, "nickname": nick,
        "verified_at": rec["verified_at"],
    }
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

ok "身份校验通过：${ME_NICK}（${ME_RED}）"
[ -n "$DATA" ] && ok "已写入 $LOCK_DIR/.owner.lock 与 ${DATA} 的 site.account"
exit 0

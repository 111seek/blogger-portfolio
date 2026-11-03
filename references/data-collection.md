# 数据采集：从账号到 data.json

作品集里每个数字都要能对上主页，所以先取数、再写字。数据分两类，来源不同。

## 一、公开数据（redbook CLI 抓）

**CLI 已随技能内置**（`vendor/redbook/`，MIT，版本见 `vendor/NOTICE.md`），对方不必先装 npm 包。
统一用启动器调用，它会自动选「全局版 → 内置副本」，并设好凭据变量：

```bash
RB="bash scripts/redbook.sh"     # 在技能根目录执行；或用绝对路径
$RB whoami                       # 先验登录态，通了再往下跑
$RB --version
```

- 想看环境到底缺什么：`bash scripts/doctor.sh`（或 `--offline` 只查本地）
- 若对方自己 `npm i -g @lucasygu/redbook` 了，启动器会优先用全局版（能跟着 npm 升级），行为一致
- 凭据文件默认 `~/.redbook/cookies.json`（0600），也可用 `REDBOOK_COOKIE_FILE` 覆盖
- 报 `No XHS session` / `route_gone` / `unauthorized` → 见文末「Cookie 修复」

```bash
# 1) 纯数字的小红书号要先解析成 userId（主页接口需要 xsec_token）
$RB search "午休日记" --json | head -c 800

# 2) 拉全量笔记（串行 + 3s 间隔，千万不要并发）
$RB user-posts <userId> --xsec-token '<token>' --xsec-source pc_search \
  --all --delay 3000 --json > posts.json
```

`posts.json.notes[]` 每条包含 `note_id / display_title / time / type / interact_info.liked_count / webUrl`。
**按 `note_id` 去重**（列表接口会重复吐条目，实测 91 → 89）。

```bash
node -e '
const d=require("./posts.json");const u=[...new Map(d.notes.map(x=>[x.note_id,x])).values()];
const num=s=>/万/.test(s)?parseFloat(s)*1e4:+s||0;
console.log("去重后", u.length);
u.sort((a,b)=>b.time-a.time).forEach(x=>console.log(new Date(x.time).toISOString().slice(0,10), num(x.interact_info.liked_count), x.display_title))'
```

### 封面图

TOP9 的封面单独取：`$RB read <noteId> --json`，取首图 URL 后 `curl` 下载，存成
`assets/note-<rank>.webp`（原图多为 webp/jpeg，**不要转格式**，build.py 会按 MIME 内嵌）。
头像：主页接口的 `image` 字段，存 `assets/avatar.webp`。

### 需要自己算的派生值

| 字段 | 算法 | 用途 |
|---|---|---|
| `quarters` | 按 `YYYY-Q` 分组，每组 `[季度标签, 篇数, 点赞合计]` | 季度曲线 |
| 中位赞 | 每篇 `liked_count` 排序取中位 | 判断账号健康度，不直接上页面 |
| 破万率 / 破千篇数 | `count(likes>=N)/总篇数` | 成绩单 |
| TOP9 | 按点赞降序取 9 条，title/like/collect/share/comment/url 照抄 | `notes[]` |
| 品牌 | 逐条看标题与正文的 `@品牌`、`#话题`、商单标识 | `brands[]`、品牌贴纸 |

`quarters` 做成 `[["24Q3",1,260],["24Q4",17,37117], ...]`，第二项是篇数（横轴下标注），第三项是点赞合计（曲线高度）。

## 二、后台数据（只能问用户要）

以下公开页面上看不到，**必须让用户提供截图或口述**，并且写进作品集前要跟他确认口径：

- 粉丝画像：城市线级、性别、年龄段占比
- 阅读量：总阅读、单篇最高阅读、破 N 万阅读的篇数占比
- 商业化：合作品牌总数、复投次数、带货成交额
- 教育 / 坐标 / 联系方式 / 过往工作经历

**口径冲突要当面报，不要自己圆。** 常见冲突：用户说「单篇最高 8 万赞」，主页显示 7.6 万；
用户说「总赞藏 10 万+」，主页显示 29.3 万。处理原则：**统一用主页能对上的数字**，
并告诉用户「面试官可能当场打开主页核对」。

## 三、Cookie 失效修复（macOS）

小红书 Cookie 走 Chrome 加密，后台进程读钥匙串会 `exit 128`。可行路径是复制 Chrome profile
到临时目录、用 headless 起 CDP、走浏览器级 `Storage.getCookies`（redbook 自带的
`Network.getAllCookies` 在新版 Chrome 已移除）：

```bash
P=/tmp/chrome-cookie-profile; rm -rf $P; mkdir -p $P/Default
cp "$HOME/Library/Application Support/Google/Chrome/Local State" $P/
cp "$HOME/Library/Application Support/Google/Chrome/Default/Cookies" $P/Default/
# 同一个 Bash 调用里启动 + 抓取（后台进程会在 shell 退出时被杀）
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --user-data-dir=$P --headless=new --no-sandbox --disable-gpu \
  --disable-dev-shm-usage --remote-debugging-port=9444 about:blank &
sleep 3 && node <抓取脚本> && kill %1
```

抓到的 cookie 拼成字符串交给 `$RB auth save --cookie-string`，写入 `~/.redbook/cookies.json`。
先试最省事的 `$RB auth save`（读本机 Chrome）；钥匙串弹窗被拒或 `exit 128` 时才走上面这套 CDP。

## 四、评论区（可选，做增长诊断时才抓）

```bash
$RB comments "<笔记URL>" --all --json > c/<noteId>.json
```

**必须串行**，每条间隔 ≥4s。实测抓到第 5 篇会弹验证码 —— 一旦出现验证码立刻停，
不要重试，否则账号 Cookie 有被风控的风险。只抓到几篇也能用：TOP1 的评论量通常占大头。

---
name: blogger-portfolio
description: 把**本人**的小红书账号数据做成一份面试用的单文件 HTML 作品集——浅色纸感、拍立得作品墙、季度曲线、成绩单 + 粉丝画像 + 总结。仅限本人账号：必须先用小红书登录，且登录账号 == 要做的账号，否则拒绝生成（不为第三方博主代做）。当用户说"给我做一个作品集/个人主页/简历网站""把我自己的账号做成面试材料""类似 whometopia 那样的页面"时使用。内置小红书 CLI（免安装）、数据采集、账号归属校验、模板、构建脚本和交付前体检。
agent_created: true
---

# 博主人设作品集（面试用单文件 HTML）

> **只做本人**。这份技能从取数到成稿都由「当前登录的小红书账号」驱动，
> 且硬性要求**登录账号 == 目标账号**，否则 `check-self.sh` 直接拒绝、`build.py` 也构建不了。
> 别人要用，就把整个技能目录打包给他，让他用自己的号登录跑一遍。
> 替第三方博主代做（抓别人的笔记、照片、商业数据）不在授权范围内——涉及他人数据与肖像，一律不接。

输出物是**一个 index.html**：图片全部 base64 内嵌，双击能开，能直接发微信/邮件给面试官。
结构固定为七个板块，用一条"生活时间线"串起来；文案只讲优势，每个数字都要能对上账号主页。

## 何时用

- 用户要把**自己的**博主账号做成投递材料（新媒体 / 内容运营 / 品牌公关岗）
- 用户已有旧版作品集，需要改配色、改结构、补成绩单
- 别人想用这套模板 → 把目录打包给他，让他用自己的账号登录后自行生成（不要代跑）

**不做**：替别人做、给别家博主出作品集、把别人账号的数据套进模板。
用户提出这类需求时，直接说明原因并给出「打包给对方自己跑」的方案，不要变通绕过校验。

## 交付物长什么样

```
portfolio/
├── index.html          ← 唯一交付物
├── data.json           ← 数据源（笔记、季度、品牌、身份）
└── assets/             ← 封面图 + 头像（构建时会被内嵌）
```

七个板块（编号主题可换，见 `references/theming.md`）：

| 板块 | 内容 | 关键要求 |
|---|---|---|
| 12:00 开场 | 标题 + 导语 + 5 格数据条 | 一句话能复述"我做出了什么" |
| 12:15 作品 | TOP1 单列拆解 + TOP2–5 常显 + TOP6–9 折叠 | 封面必须是本人出镜的原片 |
| 12:40 数据 | 季度点赞曲线 + 分享率/收藏率比率条 | 曲线平滑、带渐变面积和描线动画 |
| 13:00 经历 | 叙事 + 2×2 成绩单 + 粉丝画像 + 总结 | 数字分三级：规模/爆发/商业化 |
| 13:20 方法 | 4 条原则，每条挂一个带数字的证据 | 没有数据支撑的原则不要写 |
| 13:40 优势 | 4 张能力卡（大数字 + 标签 + 证据） | **是优势不是复盘**，严禁写问题和计划 |
| 14:00 关于 | 收尾一句 + 事实表（坐标/院校/账号/邮箱） | 方便面试官抄联系方式 |

## 前置依赖（第 0 步，取数前必做）

抓数需要小红书 CLI。**CLI 已经内置在本技能里**（`vendor/redbook/`，上游 MIT），
所以把整个技能目录拷给对方就能用，不需要他先 `npm i -g`。

```bash
bash scripts/doctor.sh     # 体检：node / CLI 来源 / cookie / 登录态
```

| 检查项 | 要求 | 不满足时 |
|---|---|---|
| node | ≥ 22 | 装 node 后再来，内置副本也靠它跑 |
| CLI | 全局 `redbook` 或 `vendor/redbook/dist/cli.js` 二者有其一 | 拷漏 vendor 了，或 `npm i -g @lucasygu/redbook` |
| 登录态 | `~/.redbook/cookies.json` 有效 | `bash scripts/redbook.sh auth save`，失败见 data-collection 文末 CDP 方案 |
| **账号归属** | **登录账号 == 要做的账号** | `bash scripts/check-self.sh --data`，不匹配会直接拒绝（见下节） |

**所有抓数命令都走启动器** `bash scripts/redbook.sh <子命令>`：它优先用全局版（能随 npm 升级），
没有再回落到内置副本，并自动设好 `REDBOOK_COOKIE_FILE`。裸写 `redbook` 在对方机器上可能不存在。

> 分享给别人：整个 `blogger-portfolio/` 目录打包即可（含 `vendor/`，约 1MB）。
> 对方那边**只有两件事要自己做**：装 node ≥22、用自己的小红书账号登录一次。
> 别把 `vendor/redbook/` 删掉换体积 —— 删了就退化成"必须先装 npm 包"。
> 想升级 CLI：`npm i -g @lucasygu/redbook@latest` 后把新版 `dist/ node_modules/` 同步进 `vendor/redbook/`。

## 0.5 身份校验（硬门槛，跳不过去）

**规则只有一条：只能给自己做。** 登录的必须是那个号，别的一律拒绝。

```bash
bash scripts/check-self.sh --data portfolio/data.json    # 校验 + 落盘，一条命令
```

它做三件事：

1. `redbook whoami --json` 拿当前登录账号（会被平台真实校验，不是读本地文件）
2. 解析 `data.json` 里的目标账号（`site.account.user_id` → 缺则从 `site.profile_url` 取），
   也支持命令行直接给 userId / 小红书号 / 昵称
3. 比对：**不一致就 exit 2 并停手**；一致才写两样东西

| 落盘物 | 作用 |
|---|---|
| `<data.json 目录>/.owner.lock` | 给 `build.py` 复核：谁、什么时候校验的（默认 7 天过期） |
| `data.json` 的 `site.account` | `{user_id, red_id, nickname, verified_at}`，页面和后续流程都以它为准 |

`build.py` 在构建前会再查一遍 lock：没有 lock、lock 的 user_id 和 `site.account.user_id` 对不上、
或超过 7 天 → **直接报错退出**，不产出 HTML。所以「手改 data.json 换成别人的号」也走不通。

示例数据（`demo/`）标了 `site.demo: true`，是虚构人物，构建时跳过校验并打印
`! 示例数据（虚构人物）：跳过账号归属校验`。真实数据不许带这个标记——两者同时出现会报错。

**目标账号不是当前登录账号时，正确的回应是停手 + 说明原因**，不是换个说法绕过：

```
这个号不是当前登录的账号，我按技能规则不能代做（涉及他人笔记数据与肖像）。
两条路：① 如果这确实是你自己的号 → 先切账号登录再跑；② 不是 → 把技能目录发给对方，让他自己跑。
```

## 流程

### 1. 取数（只取当前登录账号自己的）

数据源只有一个：**登录账号自己的笔记**。`whoami` 已经把 `user_id` 和 `xsec_token` 都给出来了，
不用再 search 猜账号，也就不会抓错人：

```bash
RB="bash scripts/redbook.sh"

# 1) 先看自己是谁（这一步失败就停，别往下走）
$RB whoami --json 2>/dev/null > me.json
UID_=$(python3 -c 'import json;print(json.load(open("me.json"))["user_id"])')
TK=$(python3 -c 'import json;print(json.load(open("me.json"))["xsec_token"])')
python3 -c 'import json;d=json.load(open("me.json"));print("采集对象：", d["nickname"], d["red_id"], d["user_id"])'

# 2) 只抓这个 user_id 的笔记
$RB user-posts "$UID_" --xsec-token "$TK" --xsec-source pc_search \
  --all --delay 3000 --json > posts.json
```

`user-posts` 返回的每条笔记都带 `user.user_id`，抓完先核一遍：全部等于 `$UID_` 才继续。
出现别人的 id 就是拿错 token 了，删掉重抓，别混进同一份数据。

阅读量、粉丝画像、品牌数、成交额这些**只能问用户要**——后台数据不公开，也只能是他自己的。

完整命令、去重与聚合脚本、Cookie 失效修复、评论抓取的反风控，见
`references/data-collection.md`。抓取务必串行 + 3s 间隔，评论遇到验证码立刻停。

### 2. 定人设皮肤

先问清三件事：**账号定位**（生活/家居/母婴/宠物/探店…）、**目标岗位**、**是否本人出镜**。
再按 `references/theming.md` 选定时间线隐喻、色板和板块命名。
默认浅色纸感（米白 `#fbf6ee` + 杏橘 `#d9744f`）；生活类博主一律不用深色。

### 3. 写 data.json

从 `demo/data.json` 复制一份改（`demo/` 是可直接构建的示例：虚构人物 + 占位封面）：

```jsonc
{
  "site":  {"title","meta","name","tagline","handle","profile_url","collected_at","start","avatar",
            "account":{"user_id","red_id","nickname","verified_at"}},   // 由 check-self.sh 自动写入，别手填
  "hero":  {"clock","h1","lead","roles"},
  "ledger":[{"value","label","hl"}],            // 5 格，第一格 hl:true
  "facts": [{"k","v"}],                          // 关于页右侧事实表（坐标/院校/账号/邮箱）
  "notes": [{"rank","title","date","like","collect","share","comment","url","brand","img"}],
  "quarters": [["24Q3", 1, 260]],               // [季度, 篇数, 点赞合计]，6–12 个都行
  "brands":[{"name","cat"}]
}
```

`site.account` 不要手写：跑 `check-self.sh --data` 会自动填，手写的值如果和登录账号不一致，
构建照样会被拦下。`profile_url` 用 `https://www.xiaohongshu.com/user/profile/<自己的 user_id>`。

`notes` 给 9 条就够（TOP1 + TOP2–5 + TOP6–9）；`img` 写相对路径，构建时自动内嵌。
数值保留平台原写法（`"7.6万"`），页面里的 `toN/fmt` 会统一换算。
`h1` 和 `lead` 里可以带 HTML（`<br>`、`<span class="mark">`、`<em>`）。

### 4. 构建

```bash
bash scripts/check-self.sh --data portfolio/data.json      # 先过身份闸（7 天有效）
python3 scripts/build.py --data portfolio/data.json --out portfolio/index.html
```

构建前会复核 `.owner.lock`：缺失、user_id 对不上、超过 7 天，都会**直接报错退出**，不出 HTML。
脚本负责内嵌图片、填充占位符，**占位符没填完同样报错退出**，最后打印还剩几处示例文案待改。

只有仓库自带的虚构 demo 能跳过校验：`python3 scripts/build.py --data demo/data.json --out demo/index.html`（靠 `site.demo: true` 识别）。真实数据不许加这个标记。

### 5. 改写示例文案（不可跳过）

模板自带一套完整的"床车午休"示例，构建后按标记逐个改掉：

```
<!--EDIT:works-->       作品区标题/导语 + TOP1 三条拆解
<!--EDIT:featured-->    TOP1 亮点卡（引言 + 为什么能火）
<!--EDIT:datahead-->    数据区标题 + 三块比率说明
<!--EDIT:experience-->  经历：叙事 + 成绩单 + 粉丝画像 + 总结
<!--EDIT:method-->      方法四条
<!--EDIT:strengths-->   优势四张
<!--EDIT:about-->       关于 + 侧栏事实表
```

写作规则、板块公式、禁忌清单、每张卡对应哪个面试问题，见 `references/copy-playbook.md`。
**动笔前先读它**，否则很容易写成复盘。

顺序建议：先 build，再在 HTML 上改文案；之后若还要改 `data.json`，记得重新 build 会覆盖手改内容。

### 6. 体检

```bash
npm i playwright-core     # 在任意临时目录装一次
node scripts/verify.js portfolio/index.html
```

三档视口（1440 / 768 / 390）各查一遍：控制台报错、可见图片是否加载、横向溢出、
滚动渐显是否露完、曲线是否生成、比率条宽度是否为 0、正文对比度是否 ≥4.5。
有硬伤时退出码非 0。

**不要给用户发截图**，只报数值结论；用户明确要看时才截图。

### 7. 交付

用 `present_files` 打开 `portfolio/index.html`，正文说清三件事：

1. 这版改了什么（配色 / 结构 / 数字口径）
2. 哪些数字和平台显示对不上、建议怎么写（**不要自己圆**）
3. 还缺什么：工作经历【待填】、联系邮箱、是否要发布成在线链接

用户常在手机上看时，走局域网预览（`~/.workbuddy/live-serve/live_serve.py`），别反复传文件。

## 目录

```
SKILL.md                      本文
scripts/check-self.sh         身份闸：登录账号 == 目标账号才放行，写 .owner.lock + site.account
scripts/build.py              data.json + 模板 → 单文件 HTML（构建前复核 .owner.lock）
scripts/verify.js             交付前体检（playwright-core + 本机 Chrome）
scripts/doctor.sh             取数前置体检（node / CLI / cookie / 登录账号）
scripts/preview.sh            构建 + 起服务 + 手机地址 + 改动自动重建（一条命令）
scripts/redbook.sh            CLI 启动器（全局版 → 内置副本，自动选）
assets/template.html          页面模板（完整 CSS/JS，占位符 {{NAME}} 形式）
demo/                         可直接构建的示例（虚构人物 + 占位封面，跑一遍验证环境）
references/data-collection.md 抓数、聚合、Cookie 修复、反风控
references/copy-playbook.md   文案公式、三级数字、禁忌、面试问题映射
references/theming.md         换人设：时间线隐喻、色板、装饰、无障碍底线
vendor/redbook/               内置小红书 CLI（MIT，含 dist/ 与 node_modules/）
vendor/NOTICE.md              内置依赖的来源、版本、许可证与升级方法
```

模板 37KB，图片内嵌后成品约 1MB —— 这个体量可以接受，别为了减体积压图。
内置 CLI 约 760KB，别删：它是"对方只装 node 就能跑"的唯一保障。

## 常见坑

- **想给别人做**：这不是"坑"是红线。登录账号和目标账号不一致时 `check-self.sh` 会 exit 2，
  `build.py` 也会因为没有 `.owner.lock` 而拒绝。**不要**去找 `demo` 标记、手写 lock、或把数据塞进
  `demo/data.json` 来绕——正确做法是把技能目录打包给对方，让他用自己的号跑一遍。
- **换了账号没重新校验**：切号后 cookie 变了、lock 还是旧号的，`build.py` 会报「账号归属记录对不上」。
  重跑 `check-self.sh --data` 即可，lock 会自动刷新。
- **数字自相矛盾**：用户口述"8 万赞"、页面写 7.6 万，面试官一核对就崩。统一取主页显示值。
- **裸写 `redbook` 报 command not found**：对方机器上没装全局包。一律用 `bash scripts/redbook.sh`，
  它会回落到 `vendor/redbook/`；先跑 `bash scripts/doctor.sh` 看是哪一环缺。
- **写成复盘**：出现"问题""下一步""学到"就是跑偏了，整块删掉换成能力卡。
- **忘记改时间戳**：导航 `<small>12:15</small>` 要和板块 `<b>12:15</b>` 同步。
- **比率条不显示**：`.bar .tr / .fl` 是 span，必须 `display:block` 才有宽度。
- **折叠区图片报"没加载"**：`display:none` 的懒加载图属正常，verify.js 已排除。
- **手机端换行**：粉丝画像三枚小卡片用了 `white-space:nowrap`，窄屏要缩字号和内边距。
- **大号账号的点赞是封顶值**：粉丝过十万级别的账号，点赞一律显示成「10 万+」，`collected_count` 也可能封顶。**任何「收藏 ÷ 点赞」的比率都只是上限，不能当结论写**——这时把比率条改成绝对值（收藏数、评论数各一组），结论一样成立，但每个数字都站得住。
- **小号的收藏率几乎为 0**：几十赞的笔记收藏常在 0–7 之间，「收藏 ÷ 点赞」全是 4%，说明不了任何事。这时把第二块比率条换成评论：`bars('cmt','comment')`（div id 同时改成 `cmt`），配合「提问式选题」讲，比收藏有信息量得多。
- **曲线在小号上会被压成平线**：纵轴现在按峰值自适应，但如果你手改过模板、把 `max` 写死成 10 万，几百赞的账号会贴底。别写死，用 `niceMax`。
- **大号别按点赞排名**：封顶之后排序是假的。改成「按内容类型各挑一条代表作」，并在小标题里说明为什么不排名。
- **封面比例混杂**：同一个账号可能同时有 9:16、3:4、4:3 三种封面（长视频、方图、横图）。统一 crop 到 3:4 + `object-position:50% 42%`，竖版不会切掉底部标题。
- **hero 数据条只占半行**：`.ledger` 放在 hero 第二个 `.wrap` 里时会继承双栏 grid，加 `.hero .wrap+.wrap{display:block}`。
- **大号取数很慢**：1000+ 篇时 `--delay 2000` 约 40 页、2 分钟能跑完；但取 TOP 9 的详情要逐篇 `read`，间隔 5s，别并发。

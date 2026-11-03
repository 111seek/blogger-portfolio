# 内置依赖说明

`vendor/redbook/` 是第三方 CLI 的**原样内置副本**，随本技能一起分发，
目的是让拿到技能的人在只有 node 的环境下也能直接取数，不必先配置 npm 全局包。

| 项 | 值 |
|---|---|
| 上游 | https://github.com/lucasygu/redbook |
| npm 包 | `@lucasygu/redbook` |
| 内置版本 | 0.8.2 |
| 许可证 | MIT（见 `vendor/redbook/LICENSE`，版权归原作者 lucasygu） |
| 内置内容 | `dist/`（编译产物）+ `node_modules/`（3 个纯 JS 运行时依赖）+ `SKILL.md` / `README.md` 原始文档 |
| 已剔除 | `*.map`、`*.d.ts`（仅调试与类型用，不影响运行） |
| 体积 | 约 760KB |

## 运行方式

`scripts/redbook.sh` 会按顺序找 CLI：`$REDBOOK_BIN` → 全局 `redbook` → `vendor/redbook/dist/cli.js`。
内置副本用 `node dist/cli.js` 直接跑，依赖从自身 `node_modules/` 解析，**不污染全局环境**。

已验证：断掉全局命令后（PATH 里只留 node），内置副本仍可正常 `whoami` 并通过真实接口取数。

## 升级方法

```bash
npm i -g @lucasygu/redbook@latest
redbook --version
# 同步进 vendor（保留目录结构，剔除 sourcemap 与类型声明）
rsync -a --exclude='*.map' --exclude='*.d.ts' \
  "$(npm root -g)/@lucasygu/redbook/" \
  vendor/redbook/
```

升级后记得更新本文件的「内置版本」一行。若上游改了 CLI 参数，同步改
`references/data-collection.md` 里的命令。

## 为什么不只写"请先 npm i -g"

分享场景下对方常常是设计师/运营，不是工程师：装 node、npm 全局路径、权限、镜像源，
任何一步卡住都会让技能停在第一步。内置一份 760KB 的副本，换掉的是"装不上"这类支持成本。

## 许可证合规

MIT 允许再分发，但要求保留版权声明与许可证全文 —— 因此 `vendor/redbook/LICENSE` 必须随目录一起保留，
不要为了减体积删掉。若将来要公开发布本技能，建议在 README 里同样注明上游出处。

## 许可边界（补充说明）

本仓库根目录的 `LICENSE` 是标准 MIT 正文，仅覆盖本仓库自有代码（模板、脚本、文档）。
`vendor/redbook/` 目录**不适用**该许可，它适用其自身 `vendor/redbook/LICENSE`（同为 MIT，版权归 lucasygu）。
两者许可兼容，因此可以一起分发；但再分发时两个 LICENSE 都要保留。

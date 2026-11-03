#!/usr/bin/env node
/**
 * 单文件作品集的交付前体检。三档视口各跑一遍：
 * 控制台报错 / 图片是否加载 / 横向溢出 / 滚动渐显是否露完 / 曲线图与比率条是否生成 / 正文对比度。
 *
 * 用法：
 *   npm i playwright-core        # 只装一次，任意临时目录
 *   node verify.js /path/to/index.html
 *
 * 依赖本机已安装 Chrome（macOS 默认路径）。退出码非 0 表示有硬伤。
 */
const path = require('path');
const fs = require('fs');

const CHROME = [
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
].find(p => fs.existsSync(p));

let chromium;
// 脚本在 skill 目录里，模块却通常装在当前目录 —— 两边都找一遍
const MODULE_PATHS = [
  'playwright-core',
  path.join(process.cwd(), 'node_modules', 'playwright-core'),
  process.env.PLAYWRIGHT_CORE || '',
].filter(Boolean);
for (const p of MODULE_PATHS) {
  try {
    ({ chromium } = require(p));
    break;
  } catch {}
}
if (!chromium) {
  console.error('✗ 缺少 playwright-core，先在当前目录执行：npm i playwright-core');
  process.exit(2);
}
if (!CHROME) {
  console.error('✗ 没找到 Chrome/Chromium，指定可执行文件或改用真实浏览器手测');
  process.exit(2);
}

const file = process.argv[2];
if (!file || !fs.existsSync(file)) {
  console.error('用法：node verify.js <index.html>');
  process.exit(2);
}
const url = 'file://' + path.resolve(file);

const lum = (s) => {
  const [r, g, b] = s.match(/\d+(\.\d+)?/g).slice(0, 3).map(Number).map((v) => {
    v /= 255;
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
const contrast = (a, b) => {
  const [l1, l2] = [lum(a), lum(b)];
  return +(((Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05)).toFixed(2));
};

const VIEWPORTS = [
  { width: 1440, height: 900, name: 'desktop' },
  { width: 768, height: 1024, name: 'tablet' },
  { width: 390, height: 844, name: 'mobile' },
];

(async () => {
  const browser = await chromium.launch({ executablePath: CHROME });
  let failed = false;

  for (const vp of VIEWPORTS) {
    const page = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
    const errors = [];
    page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
    page.on('console', (m) => m.type() === 'error' && errors.push('console: ' + m.text()));

    await page.goto(url);
    await page.waitForTimeout(900);
    // 完整滚一遍，触发懒加载和 IntersectionObserver
    await page.evaluate(async () => {
      for (let y = 0; y < document.body.scrollHeight; y += 500) {
        scrollTo(0, y);
        await new Promise((r) => setTimeout(r, 70));
      }
      scrollTo(0, 0);
    });
    await page.waitForTimeout(2600);

    const r = await page.evaluate(() => {
      const visible = (e) => e.offsetParent !== null;
      const bgOf = (el) => {
        let n = el;
        while (n) {
          const c = getComputedStyle(n).backgroundColor;
          if (c && c !== 'rgba(0, 0, 0, 0)') return c;
          n = n.parentElement;
        }
        return 'rgb(255,255,255)';
      };
      const imgs = [...document.images];
      // 折叠区里的图（display:none）不加载是预期，只统计"可见却没加载"的
      const broken = imgs.filter((i) => visible(i) && (!i.complete || i.naturalWidth === 0));
      const probe = (sel) => {
        const el = document.querySelector(sel);
        if (!el) return null;
        return { t: el.textContent.trim().slice(0, 10), ratio: 0, el };
      };
      const c = (sel) => {
        const el = document.querySelector(sel);
        if (!el) return null;
        const cs = getComputedStyle(el);
        const [tc, bc] = [cs.color, bgOf(el)];
        const f = (s) => {
          const [r, g, b] = s.match(/\d+(\.\d+)?/g).slice(0, 3).map(Number).map((v) => {
            v /= 255;
            return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
          });
          return 0.2126 * r + 0.7152 * g + 0.0722 * b;
        };
        const [l1, l2] = [f(tc), f(bc)];
        return +(((Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05)).toFixed(2));
      };
      return {
        imgs: imgs.length,
        broken: broken.map((i) => i.alt || i.dataset.note || 'img'),
        overflowX: document.documentElement.scrollWidth - window.innerWidth,
        hiddenReveal: [...document.querySelectorAll('.rv')].filter(
          (e) => visible(e) && +getComputedStyle(e).opacity < 0.99
        ).length,
        chartPath: !!document.querySelector('#qline'),
        chartLabels: document.querySelectorAll('#qchart text').length,
        bars: document.querySelectorAll('.bar .fl').length,
        barFilled: [...document.querySelectorAll('.bar .fl')].filter(
          (e) => e.getBoundingClientRect().width > 1
        ).length,
        paperBg: getComputedStyle(document.body).backgroundColor,
        contrast: { body: c('body'), lead: c('.lead'), mute: c('.mute, .ti p, .cap .m') },
        pageH: document.documentElement.scrollHeight,
      };
    });

    const issues = [];
    if (errors.length) issues.push(`${errors.length} 条控制台报错: ${errors.slice(0, 2).join(' | ')}`);
    if (r.broken.length) issues.push(`可见图片 ${r.broken.length} 张没加载: ${r.broken.slice(0, 3).join(', ')}`);
    if (r.overflowX > 0) issues.push(`横向溢出 ${r.overflowX}px`);
    if (r.hiddenReveal) issues.push(`${r.hiddenReveal} 个滚动渐显块没露出来`);
    if (!r.chartPath) issues.push('季度曲线没生成');
    if (r.bars && r.barFilled !== r.bars) issues.push(`比率条 ${r.bars - r.barFilled}/${r.bars} 宽度为 0`);
    if (r.contrast.lead && r.contrast.lead < 4.5) issues.push(`正文对比度 ${r.contrast.lead} < 4.5`);

    if (issues.length) failed = true;
    console.log(
      `${vp.name.padEnd(8)} h=${r.pageH}  图 ${r.imgs - r.broken.length}/${r.imgs}  ` +
        `对比度 ${r.contrast.lead ?? '-'}  ${issues.length ? '✗ ' + issues.join('；') : '✓ 通过'}`
    );
    await page.close();
  }

  await browser.close();
  process.exit(failed ? 1 : 0);
})();

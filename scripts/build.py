#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 data.json + 图片 + template.html 合成一个可直接投递的单文件 HTML。

用法：
    python3 build.py --data data.json --out index.html

约定：
- data.json 里所有图片字段写相对路径（相对 data.json 所在目录），会被 base64 内嵌；
  也可以直接写 http(s) 链接或 data: 开头的字符串，原样保留。
- 字段结构见 demo/data.json（可直接构建的示例，虚构人物 + 占位封面）；缺 key 直接报错，避免生成半成品。
"""
import argparse
import base64
import json
import mimetypes
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
TEMPLATE = HERE.parent / 'assets' / 'template.html'

REQUIRED = {
    'site': ['title', 'meta', 'name', 'tagline', 'handle', 'profile_url', 'collected_at', 'avatar', 'start'],
    'hero': ['clock', 'h1', 'lead', 'roles'],
}


def die(msg):
    print(f'✗ {msg}', file=sys.stderr)
    sys.exit(1)


def inline_img(value, base):
    """相对路径 → data URL；链接/data URL 原样返回；空值返回空串。"""
    if not value:
        return ''
    if value.startswith(('data:', 'http://', 'https://')):
        return value
    p = (base / value).expanduser()
    if not p.is_file():
        die(f'图片不存在：{p}')
    mime = mimetypes.guess_type(p.name)[0] or 'image/webp'
    return f'data:{mime};base64,' + base64.b64encode(p.read_bytes()).decode()


def render_ledger(items):
    out = []
    for it in items[:5]:
        cls = ' class="hl"' if it.get('hl') else ''
        out.append(f'    <div><b{cls}>{it["value"]}</b><span>{it["label"]}</span></div>')
    return '\n'.join(out)


def render_brands(items):
    cells = []
    for it in items:
        cat = f'<small>{it["cat"]}</small>' if it.get('cat') else ''
        cells.append(f'<span>{it["name"]}{cat}</span>')
    return '\n      '.join(cells)


def render_facts(items):
    return '\n'.join(f'      <li><span>{it["k"]}</span><b>{it["v"]}</b></li>' for it in items)


def check_shape(data):
    for group, keys in REQUIRED.items():
        if group not in data:
            die(f'data.json 缺少 "{group}" 段')
        for k in keys:
            if not str(data[group].get(k, '')).strip():
                die(f'data.json 缺少 {group}.{k}')
    for key in ('ledger', 'notes', 'quarters', 'brands', 'facts'):
        if not data.get(key):
            die(f'data.json 缺少 "{key}" 列表')
    if len(data['notes']) > 9:
        print('! notes 超过 9 条，只有前 9 条会展示（TOP1 单列 + TOP2-5 常显 + TOP6-9 折叠）')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--data', required=True)
    ap.add_argument('--out', default='index.html')
    ap.add_argument('--template', default=str(TEMPLATE))
    args = ap.parse_args()

    data_path = pathlib.Path(args.data).expanduser().resolve()
    base = data_path.parent
    data = json.loads(data_path.read_text(encoding='utf-8'))
    check_shape(data)

    notes = []
    for n in data['notes'][:9]:
        n = dict(n)
        n['img'] = inline_img(n.get('img', ''), base)
        notes.append(n)
    avatar = inline_img(data['site']['avatar'], base)

    slots = {
        'TITLE': data['site']['title'],
        'META': data['site']['meta'],
        'NAME': data['site']['name'],
        'TAGLINE': data['site']['tagline'],
        'HANDLE': data['site']['handle'],
        'PROFILE_URL': data['site']['profile_url'],
        'COLLECTED_AT': data['site']['collected_at'],
        'AVATAR': avatar,
        'START': data['site']['start'],
        'FACTS': render_facts(data['facts']),
        'HERO_CLOCK': data['hero']['clock'],
        'HERO_H1': data['hero']['h1'],
        'HERO_LEAD': data['hero']['lead'],
        'ROLES': data['hero']['roles'],
        'LEDGER': render_ledger(data['ledger']),
        'BRANDS': render_brands(data['brands']),
        'NOTES': json.dumps(notes, ensure_ascii=False, separators=(',', ':')),
        'QUARTERS': json.dumps(data['quarters'], ensure_ascii=False, separators=(',', ':')),
    }

    html = pathlib.Path(args.template).expanduser().read_text(encoding='utf-8')
    for k, v in slots.items():
        html = html.replace('{{' + k + '}}', str(v))

    left = sorted(set(re.findall(r'\{\{([A-Z_]+)\}\}', html)))
    if left:
        die('模板里还有没填的占位符：' + ', '.join(left))

    out = pathlib.Path(args.out).expanduser()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding='utf-8')

    todo = re.findall(r'<!--EDIT:([a-z]+)-->', html)
    print(f'✓ 已生成 {out}  ({len(html.encode("utf-8"))/1024:.0f} KB，含 {len(notes)} 条笔记)')
    print(f'  图片已内嵌：头像 1 张 + 笔记封面 {sum(1 for n in notes if n["img"])} 张')
    if todo:
        names = {
            'works': '12:15 作品区标题/导语 + TOP1 拆解',
            'featured': 'TOP1 亮点卡（引言 + 三条为什么能火）',
            'datahead': '12:40 数据区标题 + 三块比率说明',
            'experience': '13:00 经历卡片（叙事 + 成绩单 + 人群 + 总结）',
            'method': '13:20 方法四条',
            'strengths': '13:40 优势四张',
            'about': '14:00 关于 + 侧栏事实表',
        }
        print(f'! 还有 {len(todo)} 处示例文案待改写（这是模板自带的示例，必须按真实账号重写）：')
        for t in dict.fromkeys(todo):
            print(f'    · {t:<11} {names.get(t, "")}')


if __name__ == '__main__':
    main()

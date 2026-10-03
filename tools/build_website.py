#!/usr/bin/env python3
"""Generate checked-in static pages. No network, credentials or npm required."""
import json
import re
import shutil
from html import escape
from pathlib import Path
from urllib.parse import urlsplit
from user_guide import render

ROOT = Path(__file__).resolve().parents[1]

def validate(release):
    version = release.get('version')
    if version is not None and not re.fullmatch(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', version):
        raise ValueError('Use a published stable X.Y.Z version, or null before release')
    if version is not None and not re.fullmatch(r'\d{4}-\d{2}-\d{2}', release.get('date') or ''):
        raise ValueError('A published version requires its release date')
    for platform in ('windows', 'linux', 'macos'):
        for source in ('github', 'mainland'):
            url = release['downloads'][platform][source]
            if url:
                parsed = urlsplit(url)
                if not version or parsed.scheme != 'https' or not parsed.netloc or parsed.username or any(c.isspace() for c in url):
                    raise ValueError('Download links need a published version and a valid HTTPS URL')
                if source == 'github' and (parsed.netloc != 'github.com' or '/releases/download/v' + version + '/' not in parsed.path):
                    raise ValueError('GitHub assets must point to the specified release version')
    if version and not any(d['github'] or d['mainland'] for d in release['downloads'].values()):
        raise ValueError('Do not announce a version before a download is available')

def build():
    release = json.loads((ROOT/'docs/website/release.json').read_text())
    validate(release)
    out = ROOT/'website'
    (out/'images').mkdir(parents=True, exist_ok=True)
    for character, prefix in [('wei_wuxian','wwx'),('lan_wangji','lwj')]:
        for frame in (1,2):
            shutil.copyfile(ROOT/f'assets/characters/{character}/idle/{frame:02}.png', out/f'images/{prefix}-{frame}.png')
    for name in ('icon.png','hiding_icon.png'):
        shutil.copyfile(ROOT/'assets/characters/icon'/name, out/'images'/name)
    cards = []
    specs = [('windows','Windows','x64 · Intel / AMD','Windows 11 已完成基础测试；分享版新功能仍在回归。'),('linux','Linux','x64 · X11 / XWayland','Ubuntu 24.04 为当前开发环境；不支持原生 Wayland 桌面模式。'),('macos','macOS','Universal · 实验版','尚未经过 macOS 实机验证，未公证。仅供愿意协助测试的用户。')]
    for key, title, tag, description in specs:
        buttons = []
        for source, label in [('github','GitHub 下载'),('mainland','国内备用下载')]:
            url = release['downloads'][key][source]
            buttons.append(f'<a class="button primary" href="{escape(url,quote=True)}">{label} ↗</a>' if url else f'<span class="button unavailable">{label} · 准备中</span>')
        cards.append(f'<article class="platform"><h3 class="os">{title}</h3><span class="tag">{tag}</span><p>{description}</p>{"".join(buttons)}</article>')
    version = release['version']
    status = f'最新正式版 v{escape(version)} · {escape(release["date"])}' if version else '公开下载准备中 · 尚未发布正式分享版，敬请期待。'
    changelog = '<ul>' + ''.join('<li>'+escape(note)+'</li>' for note in release['notes']) + '</ul>' if release['notes'] else '<p>正在准备：对视与拥抱、互动菜单、大小设置、隐藏小兔子，以及手动检查更新。正式发布后，这里会记录每次更新。</p>'
    template = (ROOT/'docs/website/index.template.html').read_text()
    for key, value in {'RELEASE_STATUS':status,'DOWNLOAD_CARDS':''.join(cards),'CHANGELOG':changelog}.items():
        template = template.replace('{{'+key+'}}', value)
    (out/'index.html').write_text(template)
    guide = render(ROOT,'linux',version or '分享版准备中','网站指南')
    guide = guide.replace('Linux x64 · '+(version or '分享版准备中')+' 测试版 · 本指南可离线阅读','Windows / Linux / macOS · 分享版使用说明（发布前预览）' if not version else 'Windows / Linux / macOS · v'+version)
    guide = guide.replace('<body><main>','<body><main><p><a href="./">← 返回下载首页</a></p><p class="notice">本指南介绍正在准备的分享版功能。请以下载包中的指南和该版本发布说明为准。</p>' if not version else '<body><main><p><a href="./">← 返回下载首页</a></p>')
    for name in ('icon.png','hiding_icon.png'):
        guide = guide.replace('src="'+name+'"','src="images/'+name+'"')
    guide = guide.replace('许可说明见 <code>licenses/</code>；纯文字入口为 <code>README.txt</code>','下载包中另附 <code>licenses/</code> 许可说明及 <code>README.txt</code> 文字入口')
    (out/'guide.html').write_text(guide)
    (out/'version.json').write_text(json.dumps({'version':version, 'status':'published' if version else 'unreleased'},ensure_ascii=False,indent=2)+'\n')
    print('Generated website/index.html, guide.html, version.json and original artwork copies')

if __name__ == '__main__':
    build()

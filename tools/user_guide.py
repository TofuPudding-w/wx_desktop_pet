"""Render the offline, package-local getting-started guide."""
from html import escape
import json
from pathlib import Path


def render(root, target, version, build_id):
    root = Path(root)
    data = json.loads((root/'data/interactions.json').read_text())
    values = {
        'PLATFORM': {'windows':'Windows x64', 'linux':'Linux x64', 'macos':'macOS Universal · 实验版'}[target],
        'PLATFORM_NOTE': '本平台尚未经过实机测试。' if target == 'macos' else '请先关闭旧桌宠，再启动此包。',
        'VERSION':version, 'BUILD_ID':build_id,
        'EYE_COOLDOWN':str(data['natural_approach']['cooldown']),
        'HUG_COOLDOWN':str(data['hug']['cooldown']),
        'REST':str(data['hug']['rest_after']),
        'WINDOWS_OPEN':'open' if target == 'windows' else '',
        'LINUX_OPEN':'open' if target == 'linux' else '',
        'MACOS_OPEN':'open' if target == 'macos' else '',
    }
    text = (root/'docs/guide/START_HERE.template.html').read_text()
    for key, value in values.items():
        text = text.replace('{{'+key+'}}', escape(value, quote=True))
    if '{{' in text:
        raise ValueError('Unresolved guide placeholder')
    return text

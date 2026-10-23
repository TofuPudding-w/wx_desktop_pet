"""Translate the generated landing page; fail on missing Chinese copy."""
import json
import re
from html import escape
from html.parser import HTMLParser


def english_page(source, root):
    translations = json.loads((root / 'docs/website/en.json').read_text())

    def translate(text):
        key = text.strip()
        if key in translations:
            return text.replace(key, translations[key], 1)
        if match := re.fullmatch(r'(公开预览版|最新正式版) (v[\d.]+ · [\d-]+)', key):
            return ('Public preview' if match[1] == '公开预览版' else 'Latest stable release') + ' ' + match[2]
        if match := re.fullmatch(r'同一分享文件夹，请选择 (Windows|Linux|macOS) 的 ZIP。', key):
            return f'The shared folder contains all platforms. Choose the {match[1]} ZIP.'
        if key.startswith('解压整个文件夹后再运行。百度网盘'):
            version = re.search(r'v[\d.]+', key).group()
            return f'Extract the complete folder before launching. The Baidu Netdisk folder contains all platforms: choose the {version} ZIP for your system. Access codes are shown below the download buttons.'
        if re.search(r'[\u4e00-\u9fff]', key) and key != '中文':
            raise ValueError('Missing English website translation: ' + key)
        return text

    class Translator(HTMLParser):
        def __init__(self):
            super().__init__(convert_charrefs=True)
            self.output = []
        def handle_decl(self, value):
            self.output.append('<!' + value + '>')
        def handle_starttag(self, tag, attrs):
            result = []
            for key, value in attrs:
                if tag == 'html' and key == 'lang': value = 'en'
                if key in ('alt', 'aria-label') or (tag == 'meta' and key == 'content'):
                    value = translate(value)
                result.append(key if value is None else f'{key}="{escape(value, quote=True)}"')
            self.output.append('<' + tag + (' ' if result else '') + ' '.join(result) + '>')
        def handle_endtag(self, tag): self.output.append('</' + tag + '>')
        def handle_data(self, text): self.output.append(escape(translate(text), quote=False))
        def handle_comment(self, text): self.output.append('<!--' + text + '-->')
    parser = Translator()
    parser.feed(source)
    return ''.join(parser.output)

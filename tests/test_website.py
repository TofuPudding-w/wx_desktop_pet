import copy
import json
from html.parser import HTMLParser
from pathlib import Path
import sys
import unittest
from urllib.parse import urlsplit,unquote
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from build_website import validate, version_manifest, website_guides
from website_language import english_page
class Page(HTMLParser):
    def __init__(self):
        super().__init__();self.refs=[];self.ids=set()
    def handle_starttag(self,tag,attrs):
        attrs=dict(attrs)
        if 'id' in attrs:self.ids.add(attrs['id'])
        for key in ('src','href'):
            if key in attrs:self.refs.append((tag,key,attrs[key]))
class WebsiteTests(unittest.TestCase):
    def test_links_and_local_assets(self):
        for file in (ROOT/'website').glob('*.html'):
            parser=Page();parser.feed(file.read_text())
            self.assertNotIn('{{',file.read_text())
            for tag,attr,url in parser.refs:
                parts=urlsplit(url)
                if parts.scheme:
                    self.assertIn(parts.scheme,('https','mailto'))
                    self.assertEqual(tag,'a','page rendering must not require external assets')
                    continue
                destination=(file.parent/unquote(parts.path)) if parts.path else file
                self.assertTrue(destination.exists(),url)
                if parts.fragment:
                    linked=Page();linked.feed(destination.read_text())
                    self.assertIn(parts.fragment,linked.ids)
    def test_version_consistency_and_no_false_release(self):
        release=json.loads((ROOT/'docs/website/release.json').read_text())
        endpoint=json.loads((ROOT/'website/version.json').read_text())
        validate(release)
        self.assertEqual(version_manifest(release),endpoint)
        if release['version'] is None:
            self.assertEqual(endpoint['status'],'unreleased')
            self.assertNotIn('/releases/download/',(ROOT/'website/index.html').read_text())
    def test_preview_does_not_announce_stable_update(self):
        preview={'version':'0.3.0','prerelease':True,'stable_version':None}
        self.assertEqual(version_manifest(preview),{'version':None,'status':'unreleased'})
        preview['stable_version']='0.2.0'
        self.assertEqual(version_manifest(preview)['version'],'0.2.0')
        preview['prerelease']=False
        self.assertEqual(version_manifest(preview)['version'],'0.3.0')

    def test_english_page_and_download_parity(self):
        chinese = (ROOT/'website/index.html').read_text()
        english = (ROOT/'website/en.html').read_text()
        self.assertEqual(english_page(chinese, ROOT), english)
        self.assertIn('<html lang="en">', english)
        self.assertIn('guide-en.html', english)
        self.assertNotIn('Guide (Chinese)', english)
        self.assertIn('language.js', english)
        for html in (chinese, english):
            self.assertIn('index.html?lang=zh', html)
            self.assertIn('en.html?lang=en', html)
        zh, en = Page(), Page()
        zh.feed(chinese); en.feed(english)
        external = lambda page: [url for _, _, url in page.refs if url.startswith(('https:', 'mailto:'))]
        self.assertEqual(external(zh), external(en))
        with self.assertRaises(ValueError):
            english_page('<p>新增但尚未翻译的发布内容</p>', ROOT)

    def test_guides_stay_in_sync(self):
        release = json.loads((ROOT/'docs/website/release.json').read_text())
        generated = website_guides(release)
        self.assertEqual(set(generated), {'guide.html', 'guide-en.html'})
        pages = []
        for name, text in generated.items():
            self.assertEqual((ROOT/'website'/name).read_text(), text)
            self.assertIn('guide.html?lang=zh', text)
            self.assertIn('guide-en.html?lang=en', text)
            self.assertIn('language.js', text)
            page = Page(); page.feed(text); pages.append(page)
        self.assertEqual(pages[0].ids, pages[1].ids)
        self.assertIn('stories', pages[1].ids)
        self.assertIn('alarm', pages[1].ids)

    def test_release_safety(self):
        release=json.loads((ROOT/'docs/website/release.json').read_text())
        release.update(version='0.3.0',date='2026-10-03')
        release['downloads']['linux']['github']='https://github.com/TofuPudding-w/wx_desktop_pet/releases/download/v0.3.0/linux.zip'
        validate(release)
        for bad in ['javascript:alert(1)','http://example.com/pet.zip','https://github.com/TofuPudding-w/wx_desktop_pet/releases/download/v0.2.2/linux.zip']:
            broken=copy.deepcopy(release);broken['downloads']['linux']['github']=bad
            with self.assertRaises(ValueError):validate(broken)
    def test_original_art_copies(self):
        for character,prefix in [('wei_wuxian','wwx'),('lan_wangji','lwj')]:
            for frame in (1,2):
                self.assertEqual((ROOT/f'assets/characters/{character}/idle/{frame:02}.png').read_bytes(),(ROOT/f'website/images/{prefix}-{frame}.png').read_bytes())
if __name__=='__main__':unittest.main()

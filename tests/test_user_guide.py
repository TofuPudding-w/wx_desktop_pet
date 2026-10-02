from html.parser import HTMLParser
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from user_guide import render
ROOT=Path(__file__).resolve().parents[1]
class References(HTMLParser):
    def __init__(self):
        super().__init__();self.images=[];self.links=[];self.ids=set();self.script=False
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if 'id' in a:self.ids.add(a['id'])
        if tag=='img':self.images.append(a['src'])
        if tag=='a':self.links.append(a['href'])
        if tag=='script':self.script=True
class UserGuideTests(unittest.TestCase):
    def test_offline_links_and_platforms(self):
        for target in ['windows','linux','macos']:
            text=render(ROOT,target,'0.2.2','test-build')
            p=References();p.feed(text)
            self.assertFalse(p.script)
            self.assertEqual(set(p.images),{'icon.png','hiding_icon.png'})
            for link in p.links:
                self.assertTrue(link.startswith('#'))
                self.assertIn(link[1:],p.ids)
            self.assertNotIn('{{',text)
            self.assertIn('test-build',text)
            self.assertIn('5 秒',text)
            self.assertIn('30 秒',text)
            self.assertEqual(text.count('<details open>'),1)
    def test_metadata_is_escaped(self):
        text=render(ROOT,'windows','<version>','<script>')
        self.assertIn('&lt;version&gt;',text)
        self.assertNotIn('<script>',text)
if __name__=='__main__':unittest.main()

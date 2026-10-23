// Run with gjs; no browser or npm dependencies required.
const GLib = imports.gi.GLib;
const source = new TextDecoder().decode(GLib.file_get_contents('website/language.js')[1]);
let count = 0;
function check(languages, saved, query, page, expected, blocked = false) {
  let redirected = null;
  let stored = saved;
  // GJS has no browser URL global; exercise the real script with the URL subset it uses.
  class URL {
    constructor(value, base) {
      const absolute = value.startsWith('https:') ? value : base.href.replace(/[^/]*$/, value);
      const match = absolute.match(/^(https:\/\/[^?#]+)(\?[^#]*)?(#.*)?$/);
      this.path = match[1]; this.search = match[2] || ''; this.hash = match[3] || '';
      this.searchParams = { get: key => {
        const part = this.search.slice(1).split('&').find(item => item.startsWith(key + '='));
        return part ? part.slice(key.length + 1) : null;
      }};
    }
    get pathname() { return this.path.replace(/^https:\/\/[^/]+/, ""); }
    get href() { return this.path + this.search + this.hash; }
  }
  const window = {
    location: { href: 'https://example.com/' + page + query, replace: value => redirected = value },
    localStorage: { getItem: () => { if(blocked) throw Error(); return stored; }, setItem: (_,v) => { if(blocked) throw Error(); stored=v; } }
  };
  new Function('window','document','navigator','URL',source)(window,{documentElement:{lang:['en.html','guide-en.html'].includes(page)?'en':'zh-CN'}},{languages},URL);
  if ((redirected ? redirected.split('/').pop() : null) !== expected) throw Error(JSON.stringify({languages,saved,query,page,redirected,expected}));
  if(query==='?lang=zh' && !blocked && stored!=='zh') throw Error('Explicit choice was not saved');
  count++;
}
check(['en-US'],null,'','index.html','en.html');
check(['zh-TW','en-US'],null,'','index.html',null);
check(['fr-FR','en-GB'],null,'','index.html','en.html');
check(['fr-FR'],null,'','index.html','en.html');
check(['en-US'],'zh','','index.html',null);
check(['zh-CN'],'en','','index.html','en.html');
check(['en-US'],'en','?lang=zh','index.html',null);
check(['zh-CN'],'zh','?lang=en','en.html',null);
check(['en-US'],null,'#download','index.html','en.html#download',true);
check(['en-US'],null,'?lang=zh','index.html',null,true);
check(['en-US'],'invalid','','en.html',null);
check(['en-US'],null,'#hide','guide.html','guide-en.html#hide');
check(['zh-CN'],null,'#alarm','guide-en.html','guide.html#alarm');
check(['en-US'],'en','?lang=zh','guide.html',null);
check(['en-US'],null,'?lang=en#stories','guide.html','guide-en.html?lang=en#stories',true);
print('Language preference: '+count+' checks passed');

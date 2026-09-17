// ① SERPs解析: Google 検索結果ページを 1 回の実行で取り出す（javascript_tool にこのまま渡す。読み取り専用・DOM を変更しない）。
// 先に https://www.google.com/search?q=<キーワード>&hl=ja&gl=jp を navigate で開いておく（検索窓に打ち込まない）。
// 先に serp-expand.js（AIO と PAA を開く）を実行しておく。PAA の回答文と出典は、このあとの get_page_text から取る。
// 記事順位の採番（広告・AIO・知恵袋・動画を除く）は返った organic を skills/seo-analysis の定義で数える。セレクタが外れて organic が 0 件なら read_page に切り替える。
await (async () => {
  const t = e => ((e && (e.innerText || e.textContent)) || '').replace(/\s+/g, ' ').trim();
  const kw = new URLSearchParams(location.search).get('q') || '';
  const seen = new Set();
  const organic = [...document.querySelectorAll('#search a:has(h3), #rso a:has(h3)')].map(a => {
    const box = a.closest('[data-hveid], .g, div[lang]') || a.parentElement;
    return { title: t(a.querySelector('h3')), href: a.href, cite: t(box && box.querySelector('cite')).split(' ')[0],
      snippet: t(box && box.querySelector('[data-sncf], .VwiC3b, [style*="-webkit-line-clamp"]')).slice(0, 240),
      sponsored: /スポンサー|Sponsored/.test(t(box).slice(0, 40)) };
  }).filter(x => x.title && !seen.has(x.title) && seen.add(x.title));
  const aioH = [...document.querySelectorAll('h1,h2,[role=heading]')].find(e => /AI による概要|AI モード|AI Overview/.test(t(e)));
  const aioBox = aioH ? ((aioH.closest('[data-hveid]') || aioH).parentElement || aioH.parentElement) : null;
  const aio = aioBox ? { heading: t(aioH), text: t(aioBox).slice(0, 4000),
    links: [...aioBox.querySelectorAll('a[href^="http"]')].map(a => ({ text: t(a).slice(0, 80), href: a.href })).filter((x, i, arr) => arr.findIndex(y => y.href === x.href) === i).slice(0, 20),
    collapsed: !!aioBox.querySelector('[aria-expanded="false"]') } : null;
  const paa = [...new Set([...document.querySelectorAll('[data-q]')].map(e => e.getAttribute('data-q')))].filter(q => q && q !== kw);
  const related = [...new Set([...document.querySelectorAll('#botstuff a, #bres a')].map(t))].filter(s => s.length > 2 && s.length < 40);
  let suggest = [];
  try { suggest = (await (await fetch('/complete/search?client=chrome&hl=ja&q=' + encodeURIComponent(kw))).json())[1]; } catch (e) { suggest = []; }
  const acct = document.querySelector('a[aria-label*="Google アカウント"], a[aria-label*="Google Account"]');
  return { keyword: kw, searched_url: location.href, captcha: /\/sorry\//.test(location.href),
    personalized: !!acct, account_label: acct ? acct.getAttribute('aria-label') : '',
    insights_widget: /このクエリの検索パフォーマンス|Google 広告の概要/.test(document.body.innerText),
    aio, organic, paa, related, suggest };
})()

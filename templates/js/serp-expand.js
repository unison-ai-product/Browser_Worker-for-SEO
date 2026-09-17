// ① SERPs解析: AIO の「もっと見る」と、関連する質問（PAA）の最初の 4 問を 1 回の実行で開く（javascript_tool にこのまま渡す）。
// クリックを伴うので変更操作扱い（seo-start の active / b4_done / e_done が済んでいること）。開くだけで、入力・送信・遷移はしない。
// このあと serp-extract.js と get_page_text を実行する（PAA の回答文は get_page_text 側に載る）。
await (async () => {
  const t = e => ((e && (e.innerText || e.textContent)) || '').replace(/\s+/g, ' ').trim();
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const kw = new URLSearchParams(location.search).get('q') || '';
  const aioH = [...document.querySelectorAll('h1,h2,[role=heading]')].find(e => /AI による概要|AI モード|AI Overview/.test(t(e)));
  const aioBox = aioH ? ((aioH.closest('[data-hveid]') || aioH).parentElement || aioH.parentElement) : null;
  let aio_expanded = false;
  if (aioBox) {
    const more = [...aioBox.querySelectorAll('[role=button], button')].find(b => /もっと見る|Show more/.test(t(b) + (b.getAttribute('aria-label') || '')));
    if (more) { more.click(); aio_expanded = true; await sleep(1200); }
  }
  const qs = [...document.querySelectorAll('[data-q]')].filter(q => q.getAttribute('data-q') !== kw).slice(0, 4);
  let paa_opened = 0;
  for (const q of qs) { (q.querySelector('[role=button], [aria-expanded]') || q).click(); paa_opened++; await sleep(900); }
  await sleep(800);
  return { aio_found: !!aioBox, aio_expanded, paa_opened, paa_total: document.querySelectorAll('[data-q]').length };
})()

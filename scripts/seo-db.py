#!/usr/bin/env python3
"""SEO Worker 記憶 DB ヘルパー（knowledge/data/seo.db）。追記型。値の表示は JSON。

使い方:
  seo-db.py init                                   スキーマ作成（templates/db-schema.sql）
  seo-db.py stats                                  テーブル別行数
  seo-db.py history "<keyword>"                    SERP / 分析 / 構成案 / 記事の履歴
  seo-db.py serp add --keyword K --json F          ① を 1 行追記（F は serps.json）
  seo-db.py analysis add --json F                  ② を追記（配列可）
  seo-db.py outline add --json F                   ③ を追記
  seo-db.py article add --json F                   ④ を追記
  seo-db.py gate add --json F                      ゲート結果
  seo-db.py feedback add --stage S --note N [--keyword K] [--action A]
  seo-db.py knowledge add --json F                 knowledge_items を追記（配列可）
  seo-db.py knowledge search --q "語" [--kind K] [--limit 10]
  seo-db.py knowledge index                        knowledge/memory/original.md を生成（人間用索引）
  seo-db.py gsc import --csv F --range R           GSC の CSV を取り込み
  seo-db.py ga4 import --csv F --range R           GA4 の CSV を取り込み
  seo-db.py llm add --json F                       llm_citations を追記
  seo-db.py task add --json F                      task_runs を追記
環境変数 SEO_DB でパス変更可。既定は <cwd>/knowledge/data/seo.db。
接続フォルダ上で SQLite が直接開けない環境では、自動で一時領域の作業コピーを使い、終了時に正本へ書き戻す（手で複製しない）。
"""
import argparse, csv, json, os, sqlite3, sys, datetime, pathlib
import sys as _sys
if hasattr(_sys.stdout, 'reconfigure'):
    _sys.stdout.reconfigure(encoding='utf-8'); _sys.stderr.reconfigure(encoding='utf-8')

HERE = pathlib.Path(__file__).resolve().parent
DB = pathlib.Path(os.environ.get("SEO_DB", "knowledge/data/seo.db"))
SCHEMA = HERE.parent / "templates" / "db-schema.sql"


MODE = {"mode": "direct"}
_STATE = {}


def _open(path):
    c = sqlite3.connect(path, timeout=15)
    c.row_factory = sqlite3.Row
    # WAL は共有メモリが要り、接続フォルダ（ホスト PC のマウント）では使えない。単一ファイルで完結する TRUNCATE に固定（WAL で作られた既存 DB もここで切り替わる）
    c.execute("PRAGMA journal_mode = TRUNCATE")
    c.execute("BEGIN IMMEDIATE"); c.execute("ROLLBACK")  # 書き込みロックが取れるかの確認
    return c


def _work_path():
    import hashlib, tempfile
    h = hashlib.sha1(str(DB.resolve()).encode("utf-8")).hexdigest()[:12]
    d = pathlib.Path(tempfile.gettempdir()) / "seo-worker-db" / h
    d.mkdir(parents=True, exist_ok=True)
    return d / "seo.db"


def _sync_back():
    """作業コピー → 正本。接続フォルダは削除・改名ができないことがあるので、同名ファイルへの上書きだけで書き戻す。"""
    c, work = _STATE.get("conn"), _STATE.get("work")
    if not c or not work: return
    changed = c.total_changes > 0 or _STATE.get("force")
    c.close()
    if not changed: return
    import shutil
    shutil.copyfile(work, DB)
    if DB.stat().st_size != work.stat().st_size:
        sys.stderr.write(json.dumps({"error": "seo.db の書き戻しに失敗（サイズ不一致）", "work": str(work), "db": str(DB)}, ensure_ascii=False) + chr(10)); os._exit(3)


def conn():
    """knowledge/data/seo.db を開く。接続フォルダ上でファイルロックが効かず直接開けないときは、
    一時領域の作業コピーで操作して終了時に正本へ書き戻す（正本は常に knowledge/data/seo.db。SEO_DB_MODE=workcopy で強制）。"""
    DB.parent.mkdir(parents=True, exist_ok=True)
    if os.environ.get("SEO_DB_MODE") != "workcopy":
        try:
            return _open(DB)
        except sqlite3.Error:
            pass
    import atexit, shutil
    work = _work_path()
    for junk in (work, work.with_name("seo.db-journal")):
        if junk.exists(): junk.unlink()
    if DB.exists() and DB.stat().st_size > 0:
        shutil.copyfile(DB, work)
    c = _open(work)
    MODE["mode"] = "workcopy"
    _STATE.update(conn=c, work=work)
    atexit.register(_sync_back)
    return c


def out(obj):
    print(json.dumps(obj, ensure_ascii=False, indent=2, default=str))


def load_json(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return data if isinstance(data, list) else [data]


def insert(c, table, row, jsonify=()):
    row = dict(row)
    for k in jsonify:
        if k in row and not isinstance(row[k], str):
            row[k] = json.dumps(row[k], ensure_ascii=False)
    valid = [r[1] for r in c.execute(f"PRAGMA table_info({table})")]
    unknown = [k for k in row if k not in valid]
    if unknown:  # 未知の列は落として続行し、何を落としたかを stderr に出す（止めるとリトライの往復になる — 2026-09-17 実機）
        sys.stderr.write(json.dumps({"warning": f"{table} に無い列を無視: {unknown}", "columns": [v for v in valid if v not in ("id", "created_at")]}, ensure_ascii=False) + chr(10))
        row = {k: v for k, v in row.items() if k in valid}
        if not [k for k in row if k != "id"]:
            sys.stderr.write(json.dumps({"error": f"{table} に入れられる列が 1 つもありません"}, ensure_ascii=False) + chr(10)); sys.exit(2)
    cols = [k for k in row if k != "id"]
    sql = f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({', '.join('?' for _ in cols)})"
    cur = c.execute(sql, [row[k] for k in cols])
    return cur.lastrowid


def cmd_init(a):
    c = conn()
    c.executescript(SCHEMA.read_text(encoding="utf-8"))
    c.commit(); _STATE["force"] = True
    out({"ok": True, "db": str(DB), "mode": MODE["mode"]})


def cmd_stats(a):
    c = conn()
    tables = [r[0] for r in c.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'knowledge_fts%'")]
    out({t: c.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0] for t in tables})


def cmd_history(a):
    c = conn(); k = a.keyword
    out({
        "serp_runs": [dict(r) for r in c.execute("SELECT id, searched_at, aio_present, personalized, sheet_row FROM serp_runs WHERE keyword=? ORDER BY searched_at DESC LIMIT 10", (k,))],
        "article_analyses": [dict(r) for r in c.execute("SELECT id, rank, url, created_at FROM article_analyses WHERE keyword=? ORDER BY created_at DESC LIMIT 12", (k,))],
        "outlines": [dict(r) for r in c.execute("SELECT id, version, title, approved, created_at FROM outlines WHERE keyword=? ORDER BY version DESC", (k,))],
        "articles": [dict(r) for r in c.execute("SELECT id, wp_post_id, wp_url, wp_status, created_at FROM articles WHERE keyword=? ORDER BY created_at DESC", (k,))],
    })


JSON_COLS = {
    "serp_runs": ("aio_citations_json", "serp_features_json", "organic_json", "paa_json", "related_products_json", "related_searches_json", "suggest_json", "chiebukuro_json"),
    "article_analyses": ("h2_json", "h2_keywords_json", "internal_links_json", "claims_json", "aio_citation_json", "structured_data_json", "required_keywords_json"),
    "outlines": ("title_alts_json", "must_keywords_json", "route_keywords_json", "link_keywords_json", "fanout_json", "internal_links_json", "gate_result_json", "adversarial_json", "block_design_json"),
    "articles": (), "gate_results": ("detail_json",), "llm_citations": ("cited_domains_json",), "task_runs": (),
}


def cmd_add(table):
    def run(a):
        c = conn(); ids = []
        for row in load_json(a.json):
            if a.keyword:
                row["keyword"] = a.keyword
            ids.append(insert(c, table, row, JSON_COLS[table]))
        c.commit(); out({"inserted": ids, "table": table})
    return run


def cmd_feedback(a):
    c = conn()
    i = insert(c, "feedback", {"fed_at": datetime.datetime.now().isoformat(timespec="seconds"), "stage": a.stage, "keyword": a.keyword, "note": a.note, "action": a.action, "promoted_to": a.promoted_to})
    c.commit(); out({"inserted": i})


def cmd_knowledge_add(a):
    c = conn(); ids = []
    for row in load_json(a.json):
        if len(row.get("meta_description", "")) > 120:
            print(f"WARN: meta_description が 120 字を超えています: {row.get('title')}", file=sys.stderr)
        ids.append(insert(c, "knowledge_items", row))
    c.commit(); out({"inserted": ids})


def cmd_knowledge_search(a):
    c = conn()
    q = a.q.strip()
    sql = ("SELECT k.id, k.kind, k.theme, k.stance, k.title, k.meta_description, k.dated, k.source_file, bm25(knowledge_fts) AS score "
           "FROM knowledge_fts JOIN knowledge_items k ON k.id = knowledge_fts.rowid WHERE knowledge_fts MATCH ?")
    params = ['"' + q.replace('"', '""') + '"']
    if a.kind:
        sql += " AND k.kind = ?"; params.append(a.kind)
    sql += " ORDER BY score LIMIT ?"; params.append(a.limit)
    rows = [dict(r) for r in c.execute(sql, params)]
    if not rows:  # 部分一致にフォールバック（trigram FTS は 3 文字未満の語を拾えない）
        sql2 = ("SELECT id, kind, theme, stance, title, meta_description, dated, source_file FROM knowledge_items "
                "WHERE (theme LIKE ? OR title LIKE ? OR meta_description LIKE ? OR body LIKE ? OR tags LIKE ?)")
        p2 = [f"%{q}%"] * 5
        if a.kind:
            sql2 += " AND kind = ?"; p2.append(a.kind)
        rows = [dict(r) for r in c.execute(sql2 + " LIMIT ?", p2 + [a.limit])]
    out({"q": q, "hits": rows})


def cmd_knowledge_index(a):
    c = conn()
    path = pathlib.Path("knowledge/memory/original.md"); path.parent.mkdir(parents=True, exist_ok=True)
    names = {"claim": "主張・立場", "primary": "一次情報", "knowledge": "知識", "avoid": "書かないこと"}
    lines = ["# ユーザーオリジナル知識（索引ビュー。正は seo.db knowledge_items）", ""]
    for kind, label in names.items():
        lines.append(f"## {label}")
        for r in c.execute("SELECT id, theme, stance, title, meta_description, dated FROM knowledge_items WHERE kind=? ORDER BY id", (kind,)):
            st = f" | {r['stance']}" if r["stance"] else ""
            lines.append(f"- #{r['id']} | {r['theme']}{st} | {r['title']} — {r['meta_description']} ({r['dated'] or '時点不明'})")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")
    out({"written": str(path)})


def _read_csv(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def _num(v):
    if v is None: return None
    s = str(v).replace(",", "").replace("%", "").strip()
    try: return float(s)
    except ValueError: return None


def cmd_gsc_import(a):
    """GSC のパフォーマンスレポート CSV（ページ / クエリ / 表示回数 / クリック数 / CTR / 掲載順位 の列名は日英どちらでも可）。"""
    c = conn(); now = datetime.datetime.now().isoformat(timespec="seconds"); n = 0
    key = {"url": ("ページ", "Page", "上位ページ", "Top pages"), "query": ("クエリ", "Query", "上位のクエリ", "Top queries"),
           "impressions": ("表示回数", "Impressions"), "clicks": ("クリック数", "Clicks"), "ctr": ("CTR",), "position": ("掲載順位", "Position"),
           "device": ("デバイス", "Device"), "country": ("国", "Country")}
    for row in _read_csv(a.csv):
        g = lambda k: next((row[h] for h in key[k] if h in row), None)
        insert(c, "gsc_snapshots", {"captured_at": now, "date_range": a.range, "url": g("url"), "query": g("query"), "device": g("device"), "country": g("country"),
                                    "impressions": _num(g("impressions")), "clicks": _num(g("clicks")), "ctr": _num(g("ctr")), "position": _num(g("position"))})
        n += 1
    c.commit(); out({"imported": n, "range": a.range})


def cmd_ga4_import(a):
    """GA4 ランディングページレポートの CSV。列名は日英どちらでも可。無い列は NULL。"""
    c = conn(); now = datetime.datetime.now().isoformat(timespec="seconds"); n = 0
    key = {"url": ("ランディング ページ", "ランディングページ", "Landing page", "Landing page + query string"), "sessions": ("セッション", "Sessions"),
           "engaged_rate": ("エンゲージメント率", "Engagement rate"), "avg_engagement_sec": ("平均エンゲージメント時間", "Average engagement time", "セッションあたりの平均エンゲージメント時間"),
           "key_events": ("キーイベント", "Key events"), "key_event_rate": ("セッション キーイベント率", "Session key event rate")}
    for row in _read_csv(a.csv):
        g = lambda k: next((row[h] for h in key[k] if h in row), None)
        url = g("url")
        if not url: continue
        insert(c, "ga4_snapshots", {"captured_at": now, "date_range": a.range, "url": url, "sessions": _num(g("sessions")), "engaged_rate": _num(g("engaged_rate")),
                                    "avg_engagement_sec": _num(g("avg_engagement_sec")), "key_events": _num(g("key_events")), "key_event_rate": _num(g("key_event_rate"))})
        n += 1
    c.commit(); out({"imported": n, "range": a.range})


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = p.add_subparsers(dest="cmd", required=True)
    sp.add_parser("init").set_defaults(f=cmd_init)
    sp.add_parser("stats").set_defaults(f=cmd_stats)
    h = sp.add_parser("history"); h.add_argument("keyword"); h.set_defaults(f=cmd_history)
    for name, table in (("serp", "serp_runs"), ("analysis", "article_analyses"), ("outline", "outlines"), ("article", "articles"), ("gate", "gate_results"), ("llm", "llm_citations"), ("task", "task_runs")):
        g = sp.add_parser(name); gs = g.add_subparsers(dest="sub", required=True)
        ad = gs.add_parser("add"); ad.add_argument("--json", required=True); ad.add_argument("--keyword"); ad.set_defaults(f=cmd_add(table))
    fb = sp.add_parser("feedback"); fbs = fb.add_subparsers(dest="sub", required=True)
    fa = fbs.add_parser("add"); fa.add_argument("--stage", required=True); fa.add_argument("--note", required=True); fa.add_argument("--keyword"); fa.add_argument("--action"); fa.add_argument("--promoted-to", dest="promoted_to"); fa.set_defaults(f=cmd_feedback)
    kn = sp.add_parser("knowledge"); kns = kn.add_subparsers(dest="sub", required=True)
    ka = kns.add_parser("add"); ka.add_argument("--json", required=True); ka.set_defaults(f=cmd_knowledge_add)
    ks = kns.add_parser("search"); ks.add_argument("--q", required=True); ks.add_argument("--kind"); ks.add_argument("--limit", type=int, default=10); ks.set_defaults(f=cmd_knowledge_search)
    kns.add_parser("index").set_defaults(f=cmd_knowledge_index)
    for name, fn in (("gsc", cmd_gsc_import), ("ga4", cmd_ga4_import)):
        g = sp.add_parser(name); gs = g.add_subparsers(dest="sub", required=True)
        im = gs.add_parser("import"); im.add_argument("--csv", required=True); im.add_argument("--range", required=True); im.set_defaults(f=fn)
    a = p.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()

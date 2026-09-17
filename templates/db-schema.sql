-- SEO Worker 記憶 DB スキーマ v1
-- 場所: ワークスペースの knowledge/data/seo.db（scripts/seo-db.py init が作る）
-- 方針: 正本は追記型（INSERT のみ。UPDATE で履歴を消さない。最新は MAX(created_at)）。
--       成果物の正はスプレッドシート、記事の正は WP 下書き。DB は履歴・記憶・検索用。

PRAGMA journal_mode = TRUNCATE;

CREATE TABLE IF NOT EXISTS schema_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
INSERT OR IGNORE INTO schema_meta VALUES ('version', '1');

-- ① SERPs解析（1 実行 1 行。列はシート SERPs と対応。詳細は JSON）
CREATE TABLE IF NOT EXISTS serp_runs (
  id INTEGER PRIMARY KEY,
  keyword TEXT NOT NULL,
  searched_at TEXT NOT NULL,
  personalized INTEGER NOT NULL DEFAULT 0,
  aio_present INTEGER, aio_text TEXT, aio_citations_json TEXT,
  ads_top INTEGER, ads_bottom INTEGER, serp_features_json TEXT,
  organic_json TEXT,                -- [{rank,title,url,domain,snippet,meta_description}]
  paa_json TEXT, related_products_json TEXT, related_searches_json TEXT,
  suggest_json TEXT, chiebukuro_json TEXT,
  difficulty TEXT, persona TEXT, funnel TEXT, intent_explicit TEXT, intent_latent TEXT,
  sheet_row INTEGER,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_serp_kw ON serp_runs(keyword, searched_at);

-- ② 記事分析（記事ごと 1 行 + 統合行 rank=0）
CREATE TABLE IF NOT EXISTS article_analyses (
  id INTEGER PRIMARY KEY,
  serp_run_id INTEGER REFERENCES serp_runs(id),
  keyword TEXT NOT NULL,
  rank INTEGER NOT NULL,            -- 1..5, 6=知恵袋, 0=統合
  url TEXT, title TEXT,
  h2_json TEXT, h2_keywords_json TEXT,
  answer_pattern TEXT, agree TEXT, agree_reason TEXT,          -- AI見解
  best_url TEXT, best_answer TEXT, best_points TEXT, rank_factor TEXT, how_to_win TEXT,  -- AI見解
  internal_links_json TEXT, claims_json TEXT, differentiators TEXT,
  aio_citation_json TEXT, structured_data_json TEXT, llm_text_head TEXT,
  transition_map TEXT,
  required_keywords_json TEXT,      -- 統合行: {must:[], recommended:[]}
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_aa_kw ON article_analyses(keyword, created_at);

-- ③ 構成案（版ごと 1 行）
CREATE TABLE IF NOT EXISTS outlines (
  id INTEGER PRIMARY KEY,
  keyword TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  title TEXT, title_alts_json TEXT,
  must_keywords_json TEXT, route_keywords_json TEXT, link_keywords_json TEXT,
  answer TEXT, answer_basis TEXT, summary TEXT,
  skeleton TEXT,                    -- seo-outline §3 書式の本文
  aio_policy TEXT, fanout_json TEXT, internal_links_json TEXT, content_policy TEXT,
  gate_result_json TEXT, adversarial_json TEXT, block_design_json TEXT,
  approved INTEGER NOT NULL DEFAULT 0, approved_at TEXT, approval_note TEXT,
  sheet_row INTEGER,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_outline_kw ON outlines(keyword, version);

-- ④ 記事（本文は保存しない。WP 下書きの所在とゲート・監査の記録だけ）
CREATE TABLE IF NOT EXISTS articles (
  id INTEGER PRIMARY KEY,
  keyword TEXT NOT NULL,
  outline_id INTEGER REFERENCES outlines(id),
  wp_post_id INTEGER, wp_url TEXT, wp_status TEXT,      -- draft のみ
  title TEXT, slug TEXT, char_count INTEGER, figures INTEGER,
  gate_rounds INTEGER, gate_pass_at TEXT,
  psv_verdict TEXT, ov_result TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ゲート結果（機械 + 目視。周回ごと）
CREATE TABLE IF NOT EXISTS gate_results (
  id INTEGER PRIMARY KEY,
  keyword TEXT NOT NULL, stage TEXT NOT NULL,          -- outline / write
  round INTEGER NOT NULL, kind TEXT NOT NULL,          -- machine / visual
  result TEXT NOT NULL,                                -- PASS / FAIL
  detail_json TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ユーザーフィードバックメモリ（ルールフィードバック → 昇格の記録）
CREATE TABLE IF NOT EXISTS feedback (
  id INTEGER PRIMARY KEY,
  fed_at TEXT NOT NULL,
  stage TEXT NOT NULL,                                 -- serps / analysis / outline / write / other
  keyword TEXT,
  note TEXT NOT NULL,                                  -- 指摘
  action TEXT,                                         -- 対応
  promoted_to TEXT,                                    -- media-rules / gate / knowledge / null
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ユーザーオリジナル知識（user-original。1 件 1 行 + FTS）
CREATE TABLE IF NOT EXISTS knowledge_items (
  id INTEGER PRIMARY KEY,
  kind TEXT NOT NULL CHECK (kind IN ('claim','primary','knowledge','avoid')),
  theme TEXT NOT NULL,
  stance TEXT,                                         -- claim: reinforce / oppose / neutral
  title TEXT NOT NULL,
  meta_description TEXT NOT NULL,                      -- 120 字以内
  body TEXT,
  source_file TEXT, source_ref TEXT, dated TEXT, tags TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_fts USING fts5(
  title, meta_description, body, theme, tags,
  content='knowledge_items', content_rowid='id', tokenize='trigram'
);
CREATE TRIGGER IF NOT EXISTS knowledge_ai AFTER INSERT ON knowledge_items BEGIN
  INSERT INTO knowledge_fts(rowid, title, meta_description, body, theme, tags)
  VALUES (new.id, new.title, new.meta_description, new.body, new.theme, new.tags);
END;
CREATE TRIGGER IF NOT EXISTS knowledge_ad AFTER DELETE ON knowledge_items BEGIN
  INSERT INTO knowledge_fts(knowledge_fts, rowid, title, meta_description, body, theme, tags)
  VALUES ('delete', old.id, old.title, old.meta_description, old.body, old.theme, old.tags);
END;

-- GSC（ブラウザ + CSV 取り込み。追記型）
CREATE TABLE IF NOT EXISTS gsc_snapshots (
  id INTEGER PRIMARY KEY,
  captured_at TEXT NOT NULL, date_range TEXT NOT NULL,
  url TEXT, query TEXT, query_group TEXT, match_method TEXT, confidence REAL,
  device TEXT, country TEXT,
  impressions INTEGER, clicks INTEGER, ctr REAL, position REAL,
  source TEXT NOT NULL DEFAULT 'csv'
);
CREATE INDEX IF NOT EXISTS idx_gsc ON gsc_snapshots(url, query_group, captured_at);

-- GA4（ブラウザ + CSV 取り込み。出所分離。追記型）
CREATE TABLE IF NOT EXISTS ga4_snapshots (
  id INTEGER PRIMARY KEY,
  captured_at TEXT NOT NULL, date_range TEXT NOT NULL,
  url TEXT NOT NULL,
  sessions INTEGER, engaged_rate REAL, avg_engagement_sec REAL, scroll90_rate REAL,
  key_events INTEGER, key_event_rate REAL, next_page_top TEXT, source_medium_top TEXT,
  source TEXT NOT NULL DEFAULT 'csv'
);
CREATE INDEX IF NOT EXISTS idx_ga4 ON ga4_snapshots(url, captured_at);

-- LLMO 観測（AIO / AI Mode / ChatGPT / Gemini）
CREATE TABLE IF NOT EXISTS llm_citations (
  id INTEGER PRIMARY KEY,
  asked_at TEXT NOT NULL, surface TEXT NOT NULL,       -- aio / ai_mode / chatgpt / gemini
  query TEXT NOT NULL, run_no INTEGER NOT NULL DEFAULT 1,
  cited_domains_json TEXT, own_cited INTEGER, own_url TEXT, brand_mention INTEGER,
  answer_summary TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_llm ON llm_citations(query, surface, asked_at);

-- リライト候補（gsc / ga4 分析の出力）
CREATE TABLE IF NOT EXISTS rewrite_candidates (
  id INTEGER PRIMARY KEY,
  url TEXT NOT NULL, kind TEXT NOT NULL,               -- query_opt / freshness / cannibal / drift / internal_link / cv_story
  evidence_json TEXT, priority REAL,
  status TEXT NOT NULL DEFAULT 'open',                 -- open / planned / done / dropped
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- タスク実行ログ（コマンド完了時 1 行）
CREATE TABLE IF NOT EXISTS task_runs (
  id INTEGER PRIMARY KEY,
  started_at TEXT NOT NULL, finished_at TEXT,
  command TEXT NOT NULL, keyword TEXT, stage TEXT,
  result TEXT NOT NULL,                                -- ok / partial / failed / aborted
  summary TEXT
);

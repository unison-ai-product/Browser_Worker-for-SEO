# 成果物規範

## 置き場（正）

| 成果物 | 正 | 一時物 |
|---|---|---|
| SERPs 解析 | スプレッドシート `SERPs` シート + seo.db `serp_runs` | memory/work/<kw>/serps.md, serp_raw.md |
| 記事分析 | スプレッドシート `記事分析` シート + seo.db `article_analyses` | memory/work/<kw>/analysis*.md |
| 構成案 | スプレッドシート `構成案` シート + seo.db `outlines` | memory/work/<kw>/outline.md |
| 記事 | WP 下書き（post_id を seo.db `articles` に記録） | memory/work/<kw>/article.md, units/, figures/ |
| 記憶 | seo.db（feedback / gate_results）+ knowledge/feedback/lessons.md + knowledge/rules/ | — |

`memory/work/<kw>/` は同キーワードの次回実行で上書きされる。記事本文をローカルに保管する運用はしない（ユーザー決定 2026-09-16）。

## スプレッドシートの書き方

- 1 実行 = 1 行。列順は `templates/sheet-layout.md` が正本。列を増やすときは末尾に追加し既存列を動かさない。
- セル内の複数値は改行区切り（順位・URL の対応が崩れないよう「1) タイトル | URL」の形）。
- 引用は 60 字以内 + 出典 URL。他社記事本文の転載をしない。
- 記録日時は ISO8601（JST）。personalized フラグ・SERP 特徴は必ず埋める（空欄は「未取得」と書く）。

## 文書の書き方（構成案・記事）

- 見出しは `skills/seo-outline` の型、本文は `skills/seo-writing` と `knowledge/rules/media-rules.md`。
- 事実と解釈を分ける。数値は出典付き。AIO の言い換えをそのまま使わない。
- 図解は alt テキスト必須、キャプションに出典。

## 報告の書き方

結論 → スプレッドシートの行 / WP の post_id → 未解決（要出典・要人間判断）→ 次回の最適化候補。数字は表に。

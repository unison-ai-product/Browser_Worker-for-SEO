---
description: /SEO記事 の手順。標準ワーキング①〜④を1キーワードで通しで回す。到達点の指定（「構成案まで」等）があればそこで止まる。
argument-hint: <検索キーワード> [到達点]
---

# /SEO記事 — 通し実行

## 0. 前提

- 引数からキーワードと到達点を取る。到達点の語彙: `SERPsまで` / `分析まで` / `構成案まで` / `記事まで`（既定 = 記事まで）。
- キーワードが複数（読点・改行区切り）なら1本ずつ順に回す（並列にしない。Google 検索の連続入力は間隔を空ける）。
- `procedures/seo-start.md` をタスク名 `article_<キーワード>` で実行する（通しは active 1本。ステージ境界で `memory/.workflow/stage` を書き換える）。
- 過去実行の確認: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/seo-db.py history "<キーワード>"` で SERP 履歴・構成案履歴を見る。7日以内の SERP 履歴があればユーザーに「再取得するか流用するか」を1問で聞く。

## 1. ステージ実行

| ステージ | 手順書 | 主担当エージェント | 成果物の置き場 |
|---|---|---|---|
| ① SERPs解析 | procedures/seo-serps.md | serp-collector（Sonnet） | スプレッドシート `SERPs` シート + seo.db `serp_runs` |
| ② 記事分析 | procedures/seo-analysis.md | article-analyzer（Sonnet）× 上位5記事 | スプレッドシート `記事分析` シート + seo.db `article_analyses` |
| ③ 構成案 | procedures/seo-outline.md | メインループ + keyword-gate（Haiku）+ adversarial-reviewer（Opus） | スプレッドシート `構成案` シート + seo.db `outlines` |
| ④ 記事作成 | procedures/seo-write.md | unit-drafter×3 / diagram-maker（Sonnet）→ fact-checker（Haiku）→ fix-integrator（Opus） | WP 下書き（ローカル保存なし） |

各ステージの開始時に `echo "<serps|analysis|outline|write>" > memory/.workflow/stage`。
ステージ間の受け渡しは `memory/work/<kw>/` の作業ファイル（serps.md / analysis.md / outline.md / units/）。これは一時物で、正はスプレッドシートと seo.db。

## 2. ステージ境界での確認

- ①→② は自動で進む。
- ②→③ に入る前に、記事分析の要約（共通キーワード上位10・差別化要素・AIO 引用箇所）を1画面で提示する（承認不要、報告のみ）。
- ③→④ に入る前に**構成案の承認を AskUserQuestion で取る**（タイトル案・見出し階層・AIO 引用方針・内部リンク）。修正指示があれば ③ の手順9（敵対検証）からやり直し、修正内容を seo.db `feedback` に記録する。
- ④ の WP 下書き投稿前に pre-publish-verifier の VERDICT + ユーザー承認（seo-start 手順5）。

## 3. 締め

- seo-start 手順6・7（ov_done → logs → session-log → k_done）。
- 完了報告は次の順: 到達ステージ / スプレッドシートの該当シート名と行 / WP 下書きのタイトルと post_id / 次回の最適化候補（shortcut_memo）。
- 到達点で止まった場合も同じ締めを行う（k_done まで）。

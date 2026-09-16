---
description: /SEO記事 の手順。標準ワーキング①〜④を1キーワードで通しで回す。到達点の指定（「構成案まで」等）があればそこで止まる。
argument-hint: <検索キーワード> [到達点]
---

# /SEO記事 — 通し実行

## 0. 前提

- **キーワードだけの入力**（例:「不動産 相続 手続き」とだけ書かれた依頼）も /SEO記事 として扱う（既定 = 記事まで）。
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

## 2. ステージ境界（通しは止まらない）

- **/SEO記事 は承認で止まらない**。①→②→③→④→WP 下書きまで自動で進み、最後にまとめて報告する（ユーザー決定 2026-09-16「承認の深さはコマンド次第」）。ゲート（keyword-gate / fact-checker）と送信前監査（pre-publish-verifier）は省かない。監査が NO-GO なら投稿せずそこで止めて報告する。
- 段階ごとに人の確認を挟みたいときは単体コマンド（/SERPs解析 → /記事分析 → /構成案 → /記事作成）を使う。各単体コマンドはその段階の成果物を出して終わる（次段階へ勝手に進まない）。
- 構成案の分類（到達難度・想定検索者・ファネル）は AI 仮置きのまま進み、報告に `判定: AI仮置き` を付ける。
- ④ の投稿は下書きのみ（公開は人間）。投稿後のブラウザ確認（ov_done）は通しでも必須。

## 3. 締め

- seo-start 手順6・7（ov_done → logs → session-log → k_done）。
- 完了報告は次の順: 到達ステージ / スプレッドシートの該当シート名と行 / WP 下書きのタイトルと post_id / 次回の最適化候補（shortcut_memo）。
- 到達点で止まった場合も同じ締めを行う（k_done まで）。

---
name: seo-writing
description: >
  ライティングスキル — ④記事作成で unit-drafter / fix-integrator が従う本文の書き方の索引。
  出典: 「SEOライティング 基礎マニュアル」（2023-12-04 版）。中身は用途別に references/ に分解してあり、表記ルール（writing-rules）は SEO 記事以外の文章にもそのまま使える。
  Use when 「本文を書いて」「この節をリライトして」「文章を整えて」、procedures/seo-write.md の執筆・統合・推敲。
  Not for 見出し設計（→ seo-outline）、内部リンクの選び方（→ content-marketing）、サイト固有の表記差分（→ media-rules / knowledge/rules/media-rules.md が優先）。
metadata:
  version: "0.1.0"
  source: "SEOライティング 基礎マニュアル_20231204（2026-09-16 取り込み）"
  status: "ユーザー確認済み（2026-09-16）"
---

# ライティングスキル — 索引

> 読む単位を用途で選ぶ（全部読まない）。各ファイル内の **[p.N]** はマニュアルのページ。
> サイト固有の表記（統一語・トンマナ・装飾）は `knowledge/rules/media-rules.md` が**差分として**優先する。ここは一般 Web ライティングの既定。

| 用途 | 読むファイル | 使う場面 |
|---|---|---|
| 文の書き方の既定（表記・語尾・一文一義・引用・冗長・ネガティブ） | [references/writing-rules.md](references/writing-rules.md) | 執筆・統合・校正。SEO 以外の文章にも使う。gate_rules.yaml の既定はここから作る |
| 記事の組み立て（階層構造・リード文・結論ファースト・PREP / SDS・タイトル・装飾・内部リンクの種類） | [references/structure-methods.md](references/structure-methods.md) | 執筆・統合 |
| 完成時チェック（全体 8 項目・詳細 10 項目）と修正 3 回の運用 | [references/checklist.md](references/checklist.md) | keyword-gate（目視）・fix-integrator（推敲） |
| 前提概念（検索意図 4 分類・潜在ニーズ・E-E-A-T・10 工程） | [references/concepts.md](references/concepts.md) | 迷ったとき。通常は読まない |

## 本プラグインでの決まり（ユーザー決定 2026-09-16）

| 論点 | 決定 |
|---|---|
| タイトル字数 | 32 字超で警告、40 字超で FAIL（gate_rules.yaml） |
| 修正 3 回 | 同一タスク内で行う: 統合直後に 1 回目（文章全体）と 2 回目（文と単語）、WP 下書き確認時に 3 回目（修正の崩れ） |
| 記事タイプ比率 5：3：1 | プラグインでは扱わない |
| サイト固有の表記 | writing-rules を既定とし、違う部分だけ media-rules で抽出して knowledge/rules/ に置く |

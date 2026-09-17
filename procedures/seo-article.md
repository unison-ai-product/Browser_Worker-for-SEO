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

## 4. 設定の有無で変わる挙動（未設定でも止まらない）

| 設定（knowledge/config/config.yaml） | 未設定のとき | 設定済みのとき |
|---|---|---|
| `own_domain`（site-profile） | ③ の site:検索は省略し全 H2「内部リンク候補なし」。ゲートの内部リンク最小本数は警告扱い（`--profile` を渡す） | site:検索で候補を割り当て、内部リンク最小本数を FAIL 判定 |
| WP 認証メモ（`.env` / `wp*.txt`）または `wp.site_url` | ④ は投稿せず `outputs/<kw>/` に article.html・meta.md・figures/*.png を納品し、`ov_done` に `NO_POST: WP 未設定` を記録して締める | REST で下書き投稿 → 管理画面でブラウザ確認（ov_done） |
| `sheet_id` | シート追記を省略（seo.db のみ） | 各ステージでシートに 1 行追記 |
| `knowledge/rules/gate_rules.yaml` | templates の既定を使う（ゲート出力に警告） | サイトの差分入りルールで判定 |
| `knowledge/memory/original.md` | 立場 neutral、一次情報なしと明記 | 自社の主張・一次情報を構成案と本文に反映 |

未設定モードでもゲート・ファクトチェック・敵対検証・送信前監査は省かない。完了報告に未設定項目を列挙し `/SEO設定` を案内する。

## 3. 締め

- seo-start 手順6・7（ov_done → logs → session-log → k_done）。
- 完了報告は次の順: 到達ステージ / スプレッドシートの該当シート名と行 / WP 下書きのタイトルと post_id / 次回の最適化候補（shortcut_memo）。
- 到達点で止まった場合も同じ締めを行う（k_done まで）。

### 次の一手（単体実行の完了報告の最後に必ず置く）

完了報告の最後は、記事制作フローの**次の段を 1 つだけ**提案して終える。何をするか選ばせる一覧（「どれから進めますか」）は出さない。

| いま終えた段 | 次の一手 |
|---|---|
| ① SERPs解析 | `/記事分析 <キーワード>`（上位 5 記事の分析） |
| ② 記事分析 | `/構成案 <キーワード>` |
| ③ 構成案 | `/記事作成 <キーワード>`（構成案に修正指示があれば先に反映） |
| ④ 記事作成 | 人間の作業: WP 下書きの確認と公開（未設定モードなら `outputs/<キーワード>/` の確認） |

- AskUserQuestion で「次へ進む: ② 記事分析（推奨）/ ここで止める」の 2 択を 1 回だけ聞く。「次へ進む」なら同じキーワードでそのまま次の段の手順を始める（キーワードを聞き直さない。前段の成果物は `memory/work/<キーワード>/` から読む）。
- `/SEO設定` は次の一手にしない。未設定の項目は「未設定: sheet_id / own_domain / wp」の 1 行と「`/SEO設定` で埋められます」だけにとどめ、フローを設定に寄り道させない（未設定モードで ④ まで進める）。作業中に見つけた設定値の候補（例: SERP から読めた自社ドメイン）は「気づき」として 1 行で添える。推測で書き込まない。
- 通し（/SEO記事）では聞かずに次の段へ進む（§2）。

---
name: user-original
description: >
  ユーザーオリジナルスキル — ユーザーがくれる知識（自社の主張・立場、一次情報＝実測値・事例・顧客の声、その他の知識）を、主にファイルアップロードで取り込み、1 件ずつメタディスクリプションを付けて SQLite（seo.db `knowledge_items` + FTS）に格納し、構成案・執筆のときにエージェンティック検索（AI が検索語を組み立てて DB を引き、要否を判断）で見つけて使う。
  Use when 「これ覚えて」「うちの事例はこれ」「この資料を使って」「この立場は取らない」、ファイルが添付されたとき、procedures/seo-outline.md 手順4、④執筆で根拠を探すとき。
  Not for 表記・装飾のルール（→ media-rules）、サイトの分類・CTA（→ site-profile.yaml）、認証情報（.env のみ）。
metadata:
  version: "0.1.0"
  status: "ユーザー確認済み（2026-09-16）"
---

# ユーザーオリジナルスキル — メタ付き SQLite 蓄積 + エージェンティック検索

## 1. 格納先（seo.db `knowledge_items`）

1 件 = 1 行。ファイルを丸ごと 1 行にせず、**主張 1 つ・事例 1 つ・数値 1 つ**の粒度に分けて入れる。

| 列 | 内容 |
|---|---|
| id | 連番 |
| kind | `claim`（主張・立場）/ `primary`（一次情報: 実測 / 事例 / 顧客の声 / 社内データ）/ `knowledge`（その他の知識）/ `avoid`（書かないこと） |
| theme | テーマ語（施策キーワードに近い語。複数は `;` 区切り） |
| stance | claim のみ: `reinforce` / `oppose` / `neutral` |
| title | 40 字以内の見出し |
| meta_description | **120 字以内の要約**。検索の主対象。「何について・何を言っている・いつの・どの範囲の情報か」を含める |
| body | 抜粋・要点（原文の全文転載はしない。200〜600 字） |
| source_file | 取り込んだ元ファイル（knowledge/memory/sources/raw/ 内のパス）または会話 |
| source_ref | 元の位置（ページ・シート・見出し）や外部 URL |
| dated | 情報の時点（YYYY-MM） |
| tags | 自由タグ（`;` 区切り） |
| created_at | 登録日時 |

- FTS5 仮想テーブル `knowledge_fts`（title, meta_description, body, theme, tags）で全文検索。日本語は trigram トークナイザ。
- `knowledge/memory/original.md` は**人間用の索引ビュー**（`seo-db.py knowledge index` が生成）。正は DB。

## 2. 取り込み（ファイルアップロードが基本）

1. 添付ファイル（docx / pdf / xlsx / md / txt / URL）を Read する。読めない形式は変換して読む（PDF はテキスト抽出、xlsx はシートごと）。原本は `knowledge/memory/sources/raw/<日付>_<元ファイル名>` にコピー。
2. 内容を **1 件ずつ**に分け、kind / theme / stance / title / meta_description / body / dated を付けた**案を一覧で提示**し、ユーザーの承認を得てから `seo-db.py knowledge add --json <file>` で登録する（勝手に主張を作らない。承認時の修正は反映）。
3. 数値・事例は「いつ・どこの・何の数値か」を meta_description と dated に必ず入れる。無いものは `dated: 不明` で登録し、本文では使わない（fact-checker が「要出典」にする）。
4. 会話中の「覚えて」も同じ形で 1 件登録する（source_file = `conversation:<日付>`）。

## 3. エージェンティック検索（③構成案・④執筆で使う）

検索は AI が「何を探すか」を決めて DB を引き、結果の要否を判断して次の検索語を変える（1 回の全文検索で終わらない）。

1. **検索語の組み立て**: 施策キーワード・類似キーワード・H2 の語・検索意図（seo-analysis §1）から、同義語・上位概念・具体語を含む 3〜6 本の検索語を作る。
2. **実行**: `seo-db.py knowledge search --q "<語>" --kind claim|primary|knowledge|avoid --limit 10`。FTS の順位 + `theme` 一致で上位を返す（meta_description を表示）。
3. **判断**: 返った件の meta_description を読み、(a) テーマ一致 (b) 時点の新しさ (c) 記事の立場との整合 で採否を決める。足りなければ検索語を言い換えて再検索（最大 3 巡）。
4. **採用の記録**: 採用した item の id を構成案（`[一次情報: #id]`）と本文（`（出所: #id → 出典表記）`）に残す。fact-checker と pre-publish-verifier は id から原本を辿って確認できる。
5. **見つからない**ときは「一次情報なし」と明記して neutral で進める（それらしい知識を作らない）。

## 4. 使い方（場面別）

| 場面 | 検索する kind | 使い方 |
|---|---|---|
| ③構成案 手順4「あなたの検索キーワードに対する回答」 | claim | テーマ一致の主張。stance を構成案の立場にする |
| ③構成案「回答の根拠」 | primary, knowledge | 根拠として引く |
| ④執筆（E-E-A-T の経験） | primary | 「当社の〜では」と出所を明示。事例は個人が特定されない粒度 |
| ②記事分析の「AI見解」との区別 | — | AI 見解は当社の立場ではない。当社の立場は claim からだけ取る |
| ゲート・監査 | avoid | 該当する節があれば FAIL |

## 5. フィードバックとの関係

成果物への修正・評価は `knowledge/feedback/lessons.md` + seo.db `feedback`（procedures/seo-setup.md §feedback）。「主張・立場」に関わるものは `knowledge_items`（kind = claim）にも登録する。表記・構成に関わるものは media-rules へ。

## 6. 禁止

- 個人情報（顧客の氏名・連絡先・特定できる事例）を登録する。
- 認証情報を登録する（.env のみ）。
- ユーザーが言っていない主張を claim として登録する。
- 資料の全文を body に入れる（抜粋 + 参照）。

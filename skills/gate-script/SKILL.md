---
name: gate-script
description: >
  ゲートスクリプトスキル — ルール＆レギュレーションゲートの仕組み。機械判定（scripts/keyword-gate.py + gate_rules.yaml）と目視判定（keyword-gate エージェント）の分担、判定項目の正本（seo-writing/references/writing-rules.md の「可」項目と checklist.md）、PASS 証跡 gate_pass の運用、修正ループの上限、フィードバックの昇格。
  Use when procedures/seo-outline.md 手順8 / seo-write.md 手順6、gate_rules.yaml を編集するとき、「このルールを自動チェックにして」「ゲートが通らない」。
  Not for 事実確認（→ fact-checker）、ルールの中身の決定（→ writing-rules / media-rules）。
metadata:
  version: "0.1.0"
  status: "ユーザー確認済み（2026-09-16）"
---

# ゲートスクリプトスキル

## 1. 二段構え

| 段 | 担当 | 判定項目の正本 |
|---|---|---|
| 機械判定 | `scripts/keyword-gate.py` + `knowledge/rules/gate_rules.yaml` | writing-rules.md の「機械判定: 可」項目 + checklist.md の（機械）注記 + 必須キーワード網羅 |
| 目視判定 | keyword-gate エージェント（Haiku） | checklist.md の残り（魅力・流れ・結論ファースト・装飾の適切さ）+ media-rules.md の非機械項目 |

両方 PASS で `memory/.workflow/gate_pass` を Bash の echo で記録する（Publish Guard がこれを見る。Write/Edit は Flag Guard が止める）。

## 2. 機械判定の項目（gate_rules.yaml の節）

| 節 | 判定 | 既定の出どころ |
|---|---|---|
| `required_keywords` | 必須キーワードが見出し（H1〜H3）またはリード文にあるか。推奨は警告 | seo-analysis §2（3 本以上 = 必須、2 本 = 推奨） |
| `title` | 32 字超で **警告**、40 字超で **FAIL**。施策キーワードを含むか | seo-outline / writing-rules（ユーザー決定 2026-09-16） |
| `meta_description` | 140 字目安（超過は警告） | structure-methods §6 |
| `fullwidth_alnum` | 全角英数字の検出（FAIL） | writing-rules §1 |
| `replacements` | 表記ゆれ・略語の統一先辞書（左があれば FAIL、右に統一） | writing-rules §1・§2 + media-rules の差分 |
| `redundant` | 二重表現・冗長表現の辞書（FAIL） | writing-rules §2・§3 |
| `sentence_end_repeat` | 同一語尾の 3 連続（FAIL） | writing-rules §2 |
| `spoken` | ら抜き・い抜きのパターン（警告） | writing-rules §2 |
| `sentence_length` | 1 文の上限字数・読点数（警告） | writing-rules §3 一文一義 |
| `quote_source` | blockquote に出典（URL または名称）があるか（FAIL） | writing-rules §3 |
| `forbidden` | 禁止表現（ネガティブ・差別的・煽り・法規）。既定は空、media-rules の差分で追加 | writing-rules §3 + media-rules |
| `structure` | H2 飛ばしの H3、H2 数の範囲（上位記事中央値 ± 範囲は手順書が渡す） | checklist / seo-outline |
| `links` | 内部リンク最小本数、alt 欠落 | checklist |
| `placeholders` | `[要出典` `{{figure` `[[link:` `[要人間判断]` の残り（FAIL） | procedures/seo-write.md |

既定値は templates/gate_rules.yaml に収録。サイトの差分は media-rules が上書きする。

## 3. 実行

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/keyword-gate.py \
  --outline memory/work/<kw>/outline.md \        # 構成案のとき
  --article memory/work/<kw>/article.md \        # 記事のとき（どちらか）
  --required memory/work/<kw>/required_keywords.txt \
  --rules knowledge/rules/gate_rules.yaml \
  --json memory/work/<kw>/gate_result.json
```
終了コード 0 = PASS（警告のみ可）、1 = FAIL、2 = 入力不備。結果 JSON を keyword-gate エージェントに渡す。

## 4. 修正ループ

FAIL → fix-integrator（記事）/ メインループ（構成案）が FAIL 項目だけ直す → 再実行。**最大 3 周**。通らなければ止めてユーザーに報告する（基準は緩めない。例外はユーザーが gate_rules.yaml を編集して作る）。修正 3 回の運用（推敲・校正校閲・校了）は checklist.md §2。

## 5. フィードバックの昇格（ゲートスクリプト化メモリ）

lessons.md の指摘が機械判定できる形（語・数・有無）なら gate_rules.yaml に追記 → `keyword-gate.py --selftest` で判定が効くことを確認 → lessons.md の該当行に `→ gate` と印。

## 6. 禁止

- gate_pass をゲート未実行で作る／古い gate_pass を使い回す（本文を変えたら再実行）。
- FAIL を通すために required_keywords.txt から語を消す（消すのは構成案の承認をやり直してから）。

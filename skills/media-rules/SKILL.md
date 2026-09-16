---
name: media-rules
description: >
  メディアルール抽出スキル — 一般 Web ライティングの既定（seo-writing/references/writing-rules.md）と「違う部分」だけをサイト固有ルールとして抽出し、knowledge/rules/media-rules.md（人が読む差分）と gate_rules.yaml（機械判定の差分）に書く方法。入力は「ユーザー提出の文書」か「自社記事の読み取り解析」の 2 経路。
  Use when /SEO設定 rules、「うちの表記ルールを覚えて」「レギュレーションを取り込んで」「装飾ルールを確認して」。
  Not for 既定ルールそのもの（→ seo-writing/references/writing-rules.md）、個別記事の校正（→ keyword-gate / fix-integrator）。
metadata:
  version: "0.1.0"
  status: "ユーザー確認済み（2026-09-16）"
---

# メディアルール抽出スキル — 既定との差分を取る

## 1. 原則

- **既定は writing-rules.md**（一般 Web ライティング）。サイトのルールはそれとの**差分だけ**を書く。既定と同じ項目は書かない。
- 差分の書式は「既定 → 当サイト」。根拠（提出文書のどこ / どの記事のどの箇所）を必ず添える。
- 抽出結果は**ユーザーに提示して承認**を得てから knowledge/rules/ に保存する。推測で規範を確定しない。
- 記事ごとに運用が違う（矛盾）ときは「候補 A / B」を並べてユーザーに決めてもらう。

## 2. 入力の 2 経路

### 2-1. ユーザー提出

- レギュレーション文書・表記ルール表・過去の校正指摘（docx / pdf / xlsx / md / URL）を Read する。
- 文書の項目を writing-rules の項目に対応づけ、**一致するものは差分なし、違うもの・無いものを差分**として抜く。
- 文書にしか無い項目（装飾ブロックの種類、CTA の書式、画像サイズ等）はそのまま差分に入れる。

### 2-2. 自社記事の読み取り解析

- 自社の公開記事 **3 本以上**（カテゴリの異なるもの。URL はユーザーから）を WebFetch で取得。JS 描画で取れなければブラウザで開いて get_page_text（閲覧のみ）。
- 3 本に共通する慣習だけをルール候補にする（1 本だけの特徴はルールにしない）。
- WP のエディタ種別・使用ブロックは knowledge/sites/wordpress.md があれば参照。

## 3. 抽出する項目（既定と比べて見る観点）

| 区分 | 見る観点 | 既定（writing-rules） | 差分の行き先 |
|---|---|---|---|
| 文体 | 敬体 / 常体、読者への呼びかけ | です・ます調 | media-rules.md + gate_rules `style` |
| 数字・記号 | 半角 / 全角、単位、％ | 数字は半角、記号は全角 | gate_rules `limits` |
| 統一語 | 表記ゆれの統一先 | 例: Web、様々 | gate_rules `replacements` |
| 固有名詞・略語 | 正式名称で書くか、略語を許すか | 正式名称、略語不可 | gate_rules `replacements` / `allow_abbr` |
| 禁止表現 | ネガティブ・差別的・煽り・比較広告・法規（薬機法・景表法）に触れる語 | ネガティブ表現に注意 | gate_rules `forbidden` |
| 冗長・二重表現 | サイト独自に追加する語 | 既定辞書あり | gate_rules `redundant` |
| 構成 | リード文の長さ、H2 数、FAQ の有無、まとめの型、著者・更新日の表示 | 階層構造のみ | media-rules.md + gate_rules `limits` |
| 装飾 | 見出しの記法（H2 の装飾ブロック）、強調・マーカー、囲み枠、表、箇条書き、引用（blockquote）、CTA ボタン | 箇条書き 3 項目以上、blockquote に出典 | media-rules.md（HTML 記法の例を必ず添える） |
| リンク | 内部リンクの書式（ブログカード / アンカーテキスト / 画像）、外部リンクの rel、アンカーテキストの方針 | 3 種の使い分け | media-rules.md + gate_rules `limits.internal_links_min` |
| 画像 | alt の書き方、キャプション、サイズ | alt 必須 | media-rules.md + gate_rules `limits.alt_required` |

## 4. 出力の書式

### knowledge/rules/media-rules.md（人が読む）

```
## <区分>
- ルール: <既定> → <当サイト>
  - OK 例: …
  - NG 例: …
  - 根拠: <提出文書 p.N / 記事 URL の箇所>
```

### knowledge/rules/gate_rules.yaml（機械判定）

templates/gate_rules.yaml（既定 = writing-rules の「可」項目）をコピーし、差分だけを上書き・追加する。書式は gate-script。

## 5. 更新（フィードバックからの昇格）

- lessons.md に同じ指摘が 2 回 → media-rules.md の該当区分に差分として追記。
- 機械判定できる形（語・数・有無）なら gate_rules.yaml へ → `keyword-gate.py --selftest` で判定が効くことを確認。

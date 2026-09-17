---
description: 標準ワーキング③ 記事構成案作成の手順。模擬クエリファンアウト → AIO 引用テーマ → 必須見出し階層 → オリジナル主張 → site:検索で内部リンク → キーワードゲート → 敵対検証。
argument-hint: <検索キーワード>
---

# ③ 記事構成案作成

**目安 10 分**。**担当**: メインループが組み立てる。検算は keyword-gate（Haiku）、敵対検証は adversarial-reviewer（Opus, effort medium）。
**入力**: `memory/work/<kw>/serps.md` と `analysis.md`（無ければ seo.db から復元。無ければ ①② を先に）。
**スキル**: `skills/seo-outline/SKILL.md`（構成案の型）と `skills/content-marketing/SKILL.md`（見出し調整の観点）を Read。

## 手順

1. **模擬クエリファンアウト**: `skills/llmo-analysis/SKILL.md` の手順で、キーワードから Google が AIO 生成時に展開しそうなサブクエリを 6〜10 本生成（定義 / 手順 / 比較 / 費用 / 注意点 / 事例 / 最新動向 の観点）。各サブクエリが AIO 本文のどの文に対応するかを対応表にし、**AIO 一致率**（対応が取れたサブクエリ / 全サブクエリ）を出す。一致しなかったサブクエリは「AIO が拾っていない需要」として差別化候補へ。
2. **AIO 引用テーマの必須項目化**: AIO 本文を文単位に分け、各文のテーマ（定義・数値・手順・注意）を抽出。「この記事が AIO に引用されるために必ず持つべき節」として必須テーマ一覧にする（引用元の書き方 = 原文→AIO の言い換えパターンを ② から引く）。
3. **共通 SEO キーワードの見出し化**: ② の必須キーワード（3本以上）を H2、推奨（2本）を H3 候補に割り当て、検索意図の流れ（Know → Do → Buy）で階層順序を整える。
4. **ユーザーオリジナルメモリ**: `knowledge/memory/original.md`（主張・一次情報・事例・数値）と `knowledge/feedback/lessons.md` を読み、差別化要素（② 手順9）と突き合わせて**自社だけが書ける節**を最低 1 つ入れる。無ければ「一次情報が無い」と明記し、ユーザーに 1 問で「入れたい主張・事例はあるか」を聞く（無回答なら中立の立場で進める）。
5. **タイトルと見出しの作成**: skills/seo-outline の型（タイトル 32 字・H2 3〜6・H3 各 1〜3・FAQ 3〜5・まとめ）で第1案を書く。
6. **site:検索で内部リンク候補**（`own_domain` が空なら省略し、全 H2 を「内部リンク候補なし（未設定）」とする）: **検索は 1 回だけ**（H2 ごとに検索しない）: まず WebFetch で `https://<own_domain>/wp-json/wp/v2/search?search=<キーワードの主要語>&per_page=30&_fields=title,url`（WordPress の公開検索 API。GET のみ・認証不要）を引き、取れなければ Claude in Chrome で `https://www.google.com/search?q=site:<own_domain>+<キーワードの主要語>&num=30` を navigate して serp-extract.js で一覧を取る。返った一覧から各 H2 に合う記事を割り当てる。各 H2 に 0〜2 本の自社記事（タイトル・URL）を割り当て、無い H2 は「内部リンク候補なし（新規記事候補）」と記録。
7. **コンテンツマーケティング観点の調整**: skills/content-marketing の観点（読者の段階・CTA の位置・次に読ませる記事）で H2 の順序と FAQ を調整。
8. **キーワードゲート**: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/keyword-gate.py --outline memory/work/<kw>/outline.md --required memory/work/<kw>/required_keywords.txt --keyword "<kw>" --h2-median-file memory/work/<kw>/h2_median.txt --profile knowledge/config/config.yaml --rules knowledge/rules/gate_rules.yaml`（outline.md は記事の骨組みだけ。ファンアウト・内部リンク・方針は outline_notes.md に書く） を実行し、必須キーワードの網羅・タイトル字数・見出し数・禁止語を機械判定。FAIL 項目は直してから再実行。keyword-gate（Haiku）に「機械判定の結果と構成案を渡して抜け漏れの目視検算」を委譲してよい。
9. **敵対検証**: adversarial-reviewer（Opus）に「上位5記事の見出し構成（② の analysis_*.md）と本構成案」を渡し、(a) 上位記事に負ける節 (b) AIO に引用されない理由 (c) 検索意図とズレる節 (d) 自社の主張が弱い節、を指摘させる。指摘を反映して第2案にし、再度手順8 のゲートを通す（敵対検証は **1 回だけ**。第2案を再レビューに出さない。ゲートの再実行は通るまで・最大 2 周）。
10. **記録**: `memory/work/<kw>/outline.md`（最終案）、スプレッドシート `構成案` シートに 1 行（タイトル / 見出し階層 / AIO 引用方針 / 内部リンク / コンテンツ方針 / ゲート結果 / 敵対検証の要点）、seo.db `outlines` に追記。
11. 完了報告。通し（/SEO記事）ならそのまま ④ へ進む。単体 /構成案 ならここで終わり、ユーザーの修正指示があれば反映して seo.db `feedback` に記録する。最後に「次の一手」（procedures/seo-article.md §3。③ の次は `/記事作成`）を 1 つだけ提案する。

## 成果物の定義

- タイトル（第1候補 + 代替2つ）
- 見出し階層（H2/H3、各見出しに「必須KW」「AIO 引用テーマ」「内部リンク」のタグ）
- AIO 引用方針（引用されたい文を「AとはBである」形で先に書く、数値は出典付き、等）
- 見出し配下内部リンク（H2 → 自社記事）
- コンテンツ方針（立場 reinforce/oppose/neutral・オリジナル要素・一次情報の有無・想定文字数）

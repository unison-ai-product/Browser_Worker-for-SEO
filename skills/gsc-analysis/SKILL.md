---
name: gsc-analysis
description: >
  GSC分析スキル — Google Search Console の検索パフォーマンスから記事ごとの表示回数・クリック・CTR・掲載順位・クエリを読み、リライト候補（クエリ最適化 / フレッシュネス / 内部リンク / カニバリ）を機械的に出す観点と安全境界。v0.2 の /SEO分析・/リライト の前段。
  Use when 「GSCを見て」「どの記事をリライトすべき？」「順位が落ちた記事は？」「取れているクエリは？」「カニバってる？」。
  Not for GA4 のコンバージョン（→ ga4-analysis）、SERP の生データ（→ seo-analysis）、AI 検索の引用（→ llmo-analysis）。
metadata:
  version: "0.1.0"
  status: "ユーザー確認済み（2026-09-16）"
---

# GSC分析スキル

> 判定はすべて**決定的（LLM を使わない）**に行い、しきい値は knowledge/config/analysis.yaml に置く（既定は templates/analysis.example.yaml）。

## 1. 安全境界（search-console-jp より）

| 操作 | 可否 |
|---|---|
| 各種レポートの閲覧・エクスポート、生成 AI パフォーマンスレポートの取得、URL 検査（確認のみ） | 自律可 |
| インデックス登録リクエスト、sitemap 送信 | ゲート下で可（1 URL ずつ・少数。送信先 URL を読み上げて確認） |
| 削除ツール（Removals）、所有権の変更・削除、ユーザー権限、プロパティ削除、クロール設定 | **AI 不可**（人間） |

## 2. 取得する項目

| 項目 | 内容 | 制約 |
|---|---|---|
| 検索パフォーマンス（ページ × クエリ × 日） | 表示回数 / クリック / CTR / 掲載順位 / デバイス / 国 | API は 50,000 行/日/プロパティ/検索タイプ、1 リクエスト 25,000 行 + startRow、UI は 1,000 行  |
| 期間 | リライト候補判定は**直近 3 か月**。実施後の評価は 1 か月（主）/ 3 か月（副）/ 6 か月（長期）  | 日次で正規化して保存（追記型） |
| 生成 AI パフォーマンスレポート（Beta） | AI Overviews / AI Mode の表示回数（ページ・国・デバイス・日）。**クリック・CTR・順位・クエリは出ない** | 通常レポートにも含まれているので**足し算しない**（二重計上）。出なければ `未提供` と記録（FAIL にしない）  |

## 3. クエリの正規化（Match Cascade）

同じ意図のクエリを 1 グループにまとめてから判定する。段階と信頼度を必ず記録する:

| 段階 | 判定 |
|---|---|
| exact | 完全一致 |
| synonym | 統一語辞書（表記ゆれ・同義） |
| containment | 包含（「A B」⊂「A B C」） |
| co_landing | 同じランディング URL + トークン重なりがしきい値以上 |
| serp_verified | SERP 上位 URL の重なりで確認 |
| unmatched | どれにも当たらない |

## 4. 期待 CTR と残差（固定の AIO 減衰率を仮定しない）

- **自サイトの「順位 × デバイス × 意図」別の期待 CTR** を基線にし、実 CTR との残差 `realizable_ctr` を出す。新規サイトは一般の順位別 CTR を事前値にし、自データが増えたら寄せる。
- **AIO による CTR 減少率を固定値で仮定することは禁止**。AIO の影響は `aio_pressure`（ゼロクリック側の損失）と引用機会に分けて別に持つ。
- AIO は 1 ブロック = 1 順位・表示回数は 1 に重複排除される。

## 5. リライト候補の判定（種別ごと）

| 種別 | 判定（決定的） | 参照 |
|---|---|---|
| クエリ最適化（タイトル・ディスクリプション） | 順位帯が同じで**期待 CTR に対する残差が継続して負**のページ。`aio_suppressed`（AIO 起因）は除外する。効果は**同じ順位帯の中で**前後比較 | rewrite-runtime REQ-RWR-09 |
| クエリ最適化（見出し追加） | 順位 11〜20 で表示回数の多いクエリが見出しに無い | 一般 |
| フレッシュネス | 3 か月前比で表示回数が一定率以上減、かつ更新日が古い | しきい値は analysis.yaml |
| カニバリ | 同一クエリグループで 2 URL 以上が表示され、順位が入れ替わっている | KGA（coverage / cannibalization） |
| Query Drift | 記事が取っているクエリグループが当初の施策キーワードから離れている | KGA |
| 内部リンク | カニバリの従側・順位 11〜20 の記事に、主側・上位記事からのリンクが無い | content-marketing |

各候補に「根拠指標（数値と期間）」「順位帯」「AIO 影響の有無」を付ける。優先度は「表示回数 × 改善余地」で並べる。

## 6. 記録

seo.db `gsc_snapshots`（url, query_group, match_method, confidence, date_range, impressions, clicks, ctr, position, device, captured_at）と `rewrite_candidates`（url, kind, evidence_json, priority, created_at）に追記型。

## 7. 出力

リライト候補の表（URL / 種別 / 根拠指標 / 順位帯 / AIO 影響 / 優先度）。実施は /リライト（v0.2）。

## 8. 決まり（ユーザー決定 2026-09-16）と未確定

- **取得経路: ブラウザ操作（Claude in Chrome でログイン済み画面）+ CSV エクスポートの取り込み**。API は使わない（v0.2 で検討）。CSV は `memory/work/gsc/<日付>/` に置き、`seo-db.py gsc import` で追記する。
- 未確定: しきい値の既定値（フレッシュネスの減少率・カニバリの順位入替回数・co_landing の重なり率）。templates/analysis.example.yaml に `null` で置き、/SEO設定 で決める。

# SEO Content Worker for Claude Cowork

SEO 記事のコンテンツ制作を、①SERPs解析 → ②記事分析 → ③構成案 → ④記事作成・WP 下書きの 4 段階で回す Cowork プラグイン。
ブラウザ操作は browser-worker（Delvework）のゲート機構を同梱して自己完結。サブエージェントは Sonnet 実行 / Haiku 検査 / Opus 統合判断の 3 層。成果物はスプレッドシート、記事は WP 下書きのみ、記憶は SQLite。

## セットアップ

1. Cowork の設定 → プラグインでこのリポジトリを marketplace として追加し **seo-content-worker** を有効化。
2. Claude in Chrome をコネクタで ON（Google・WP のログイン済みブラウザを使う）。Google ドライブ連携も ON（スプレッドシート出力）。
3. `/SEO設定` を順に: `db`（SQLite 初期化）→ `sheet`（成果物シート・キーワードマップ）→ `wp`（サイト URL・投稿方法。REST を使うならアプリケーションパスワードを **あなたが** `.env` に置く）→ `profile`（想定検索者・ファネル・カテゴリ・CTA などサイト固有の値）→ `rules`（表記・装飾の差分抽出）→ 必要なら `memory`（自社の主張・一次情報の取り込み）。

## 使い方

| コマンド | やること |
|---|---|
| `/SEO記事 <キーワード> [構成案まで]` | ①〜④を通しで WP 下書きまで止まらず進む（ゲート・監査あり、公開は人間）。キーワードだけの入力でも同じ |
| `/SERPs解析` `/記事分析` `/構成案` `/記事作成` | 各段階の単体実行。その段階で止まるので、確認を挟みたいときはこちら |
| `/SEO設定` | 設定・記憶・機能 ON/OFF |
| `/SEO検証` | セルフテストと状態確認 |

普通に「〇〇で記事作って」と頼むか、キーワードだけ打てば `/SEO記事` に振り分けます。

## 安全設計（機械強制）

- **Workflow Gate**: ブラウザの変更操作はタスク開始（フェーズ判定・変更前記録）を通すまで拒否。
- **Publish Guard**: WP への公開（publish / future / private）は常に拒否。下書きも、ルール＆レギュレーションゲート PASS の証跡が無ければ拒否。
- **Subagent Guard**: 配役表（docs/agent-roster.md）に無いサブエージェントは起動不可。
- **RM Guard / Flag Guard / Drop Guard / Injection Warn**: 一括削除の拒否、フラグの手書き禁止、締め忘れの警告、ページ由来の指示への注意喚起。

公開・削除・設定変更・認証情報の入力は人間が行います。

## 構成

```
commands/      入口 7 本（日本語）→ procedures/ の手順書を Read
procedures/    seo-start（タスク開始）/ seo-article（通し）/ seo-serps / seo-analysis / seo-outline / seo-write / seo-setup / seo-verify
skills/        seo-analysis / seo-outline / content-marketing / seo-writing(references 4 分割) / media-rules / gate-script / diagram-maker / llmo-analysis / gsc-analysis / ga4-analysis / user-original
agents/        serp-collector, article-analyzer, unit-drafter, diagram-maker（Sonnet）/ fact-checker, keyword-gate, pre-publish-verifier（Haiku）/ fix-integrator, adversarial-reviewer（Opus）
hooks/         hooks.json + scripts（ゲート 8 本 + session-rules.txt）
templates/     sheet-layout.md（列定義）/ db-schema.sql / config.yaml / site-profile.example.yaml / gate_rules.yaml / analysis.example.yaml / figure.html
scripts/       seo-db.py（SQLite）/ wp-draft.py（REST 下書き）/ keyword-gate.py（機械判定）/ test-hooks.sh
docs/          steps-reference / agent-roster / command-registry / conventions / steps/
```

ワークスペース側（プラグインには含めない）: `knowledge/`（config / rules / memory / data/seo.db / logs / sites）、`memory/`（.workflow フラグ・作業ファイル）、`.env`。

## ライセンス

MIT License（LICENSE を参照）。

## 予定（v0.2）

`/SEO分析`（GSC・GA4・LLM 引用）、`/リライト`（クエリ最適化・CV ストーリー・内部リンク・フレッシュネス）、定期巡回。入口は未作成、スキル（gsc-analysis / ga4-analysis / llmo-analysis）は v0.1 に同梱。

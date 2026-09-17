# SEO Content Worker for Claude Cowork

> **利用者向けの配布はこちら → https://github.com/UNISON-TECHNOLOGY/seo-content-worker** （marketplace に追加する URL・`.plugin` のダウンロードはこのリポジトリ。ログイン不要）
> `unison-ai-product/Browser_Worker-for-SEO` は開発用で、`main` は作業中の状態を含みます。

SEO 記事のコンテンツ制作を、①SERPs解析 → ②記事分析 → ③構成案 → ④記事作成・WP 下書きの 4 段階で回す Cowork プラグイン。
ブラウザ操作は browser-worker（Delvework）のゲート機構を同梱して自己完結。サブエージェントは Sonnet 実行 / Haiku 検査 / Opus 統合判断の 3 層。成果物はスプレッドシート、記事は WP 下書きのみ、記憶は SQLite。

## セットアップ

1. Cowork の設定 → プラグインで次の URL を marketplace として追加し **seo-content-worker** を有効化。
   `https://github.com/UNISON-TECHNOLOGY/seo-content-worker`
   - 公開リポジトリなので GitHub ログインは不要。ログインを求められたら URL の打ち間違い（組織名は `UNISON-TECHNOLOGY`、リポジトリ名は `seo-content-worker`）。存在しない URL だと GitHub が非公開扱いで認証を求めてくる。
   - Git を使わない入れ方: [Releases](https://github.com/UNISON-TECHNOLOGY/seo-content-worker/releases/latest) の `.plugin` ファイルをダウンロードして Cowork にドラッグ。
2. Claude in Chrome をコネクタで ON（Google・WP のログイン済みブラウザを使う）。Google ドライブ連携も ON（スプレッドシート出力）。
3. `/SEO設定` を実行（引数なし）。保存先フォルダ → 記憶 DB → サイトプロファイル → スプレッドシート → WordPress → 表記ルールの順に案内され、済んだ段は飛ばして続きから再開する。必須は最初の 2 つだけで、残りは「あとで」を選べる（空の間は未設定モードで動く）。WP を REST で使うなら、アプリケーションパスワードは **あなたが** 保存先フォルダ直下のテキストファイル（`.env` または `wp*.txt`、2 行）に置く。チャットには貼らない。

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
scripts/       seo-db.py（SQLite）/ wp-draft.py（REST 下書き）/ keyword-gate.py（機械判定）/ verify.sh（検証一式）/ test-hooks.sh
docs/          steps-reference / agent-roster / command-registry / conventions / steps/
```

ワークスペース側（プラグインには含めない）: `knowledge/`（config / rules / memory / data/seo.db / logs / sites）、`memory/`（.workflow フラグ・作業ファイル）、`.env` / `wp*.txt`（WP 認証。人間が置く）。

## ライセンス

MIT License（LICENSE を参照）。

## 予定（v0.2）

`/SEO分析`（GSC・GA4・LLM 引用）、`/リライト`（クエリ最適化・CV ストーリー・内部リンク・フレッシュネス）、定期巡回。入口は未作成、スキル（gsc-analysis / ga4-analysis / llmo-analysis）は v0.1 に同梱。

## リリース

- 開発は `unison-ai-product/Browser_Worker-for-SEO`、配布は `UNISON-TECHNOLOGY/seo-content-worker`（利用者が marketplace に追加するのは配布側だけ）。配布側はタグ `vX.Y.Z` を切ったときだけ更新されるので、開発中の `main` は利用者に届かない。
- 配布物は `python scripts/build-dist.py --out <dir>`（Git 管理下のファイルから `.github/` などの開発専用を除いたもの）。Release ワークフローがこれを配布リポジトリの `main` に同期し、同じタグと `.plugin` 付き Release をそちらに作る。Secret `DIST_REPO_TOKEN`（配布リポジトリの Contents: Read and write の fine-grained PAT）が必要。
- 版上げは `.claude-plugin/plugin.json` と `marketplace.json` の `version` を揃え、CHANGELOG.md の `[Unreleased]` を `[X.Y.Z] - 日付` に切ってから `git tag vX.Y.Z && git push origin vX.Y.Z`。Release ワークフローが `verify.sh --release`（タグ・version・CHANGELOG の整合）→ `.plugin` ビルド → CHANGELOG の該当節を本文にした Release 作成を行う。
- ローカル検証は `bash scripts/verify.sh`（CI と同じ内容。`/SEO検証` もこれを呼ぶ）。

# Changelog

形式は [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/)、版は [Semantic Versioning](https://semver.org/lang/ja/)。
タグ `vX.Y.Z` の Release ノートはこのファイルの該当節を正とする。

## [Unreleased]

### Added
- `scripts/verify.sh` — CI / Release / `/SEO検証` が共通で呼ぶ検証コマンド（manifests・構造・スクリプト・hooks・DB・WP 拒否・リリース整合）
- CHANGELOG.md

## [0.1.0] - 2026-09-16

### Added
- 入口コマンド 7 本（/SEO記事 /SERPs解析 /記事分析 /構成案 /記事作成 /SEO設定 /SEO検証）と手順書 8 本
- スキル 11 本（seo-analysis / seo-outline / content-marketing / seo-writing(references 4 分割) / media-rules / gate-script / diagram-maker / llmo-analysis / gsc-analysis / ga4-analysis / user-original）
- サブエージェント 9 体（Sonnet 実行 4 / Haiku 検査 3 / Opus 統合判断 2）
- フック: Workflow Gate / Publish Guard / Subagent Guard / RM Guard / Flag Guard / Drop Guard / Injection Warn / SessionStart
- テンプレート: スプレッドシート列定義、SQLite スキーマ（knowledge_items + FTS5）、config、site-profile 例、gate_rules、analysis 例、figure.html
- スクリプト: seo-db.py（SQLite）、wp-draft.py（REST 下書きのみ）、keyword-gate.py（機械判定）、test-hooks.sh
- CI（構造検証・hooks・selftest・DB）と Release（タグ push で `.plugin` を添付）ワークフロー
- MIT License

### Decided
- キーワードだけの入力は /SEO記事 として WP 下書きまで承認なしで進む。単体コマンドはその段階で止まる
- 公開（publish / future / private）は AI 不可。下書きもゲート PASS の証跡が無ければ不可
- 成果物はスプレッドシート、記事は WP 下書きのみ、記憶は SQLite

[Unreleased]: https://github.com/unison-ai-product/Browser_Worker-for-SEO/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/unison-ai-product/Browser_Worker-for-SEO/releases/tag/v0.1.0

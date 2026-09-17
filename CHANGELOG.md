# Changelog

形式は [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/)、版は [Semantic Versioning](https://semver.org/lang/ja/)。
タグ `vX.Y.Z` の Release ノートはこのファイルの該当節を正とする。

## [Unreleased]

### Fixed（実機の通し 1 本・3 時間のログから）
- 自社記事が同じクエリの上位にいるのに新規記事を最後まで作り、③ の敵対検証で重複が分かってリライトに切り替え（③④ がやり直し）→ ① で `own_in_serp` を記録し、10 位以内にあれば ② の前に 1 回だけ「リライト案 / 新規 / 止める」を聞く。リライト案のゲートは完成形（差分を差し込んだもの）にかける
- seo-db.py: JSON に未知の列があると exit 2 で止まり、2 回リトライしていた → 未知の列は落として続行し、落とした列を stderr に出す
- ④ ゲートが語尾の 3 連続 11 件で 1 周増えた → unit-drafter に gate_rules.yaml を書く前に読ませる
- fix-integrator: 要出典・要人間判断の申し送りは最初から handover.md に分ける。本文修正で図の文言が変わったら HTML・alt・PNG を作り直す
- 図解の PNG 化: `scripts/figures-png.py`（コンテナ内の Playwright で全図を 1 回で撮る）を第一に。クラウドではユーザーのブラウザからコンテナの localhost に届かない

## [0.2.5] - 2026-09-17

### Changed
- メイン（会話の本体）を「ステップ進行役」に限定: 読み解く・組み立てる・書くはサブエージェントに渡し、メインは起動・ファイルの受け渡し・フラグ・ブラウザ操作・スクリプト実行だけ（メインのモデルが何であっても所要時間が変わらないように）。① の抽出は serp-collector へ必ず委譲、② の統合・③ の構成案の組み立てと修正・④ のユニット brief は新設の outline-builder（Sonnet, effort medium, ツールは Read/Write/Edit、呼び出し上限 14 回）へ
- 用語: 「メインループ」→「メイン（ステップ進行役）」（ワークフローはループではなくステップ）
- 機械的な作業の Sonnet 3 体（serp-collector / article-analyzer / diagram-maker）のエフォートを medium → low に。本文を書く unit-drafter と Opus の 2 体（敵対検証・統合）は medium のまま

## [0.2.4] - 2026-09-17

### Fixed（仕様メモとの突合で見つけたずれ。v0.2.3 の速度改善で入れてしまった分を含む）
- ④-1「順次作成」: v0.2.3 で 3 体同時にした執筆を U1→U2→U3 の順次に戻す。速さは「次ユニットの執筆と前ユニットのファクトチェックを同時に起動する」流し方で確保（④-3「完了ユニット単位で事実確認」どおり）
- ③-6「site:検索で見出しのキーワードごとにピックアップ」: v0.2.3 で WordPress 検索 API 優先・1 回にしたのを、H2 ごとの site: 検索に戻す（検索窓に打たず 1 往復にまとめる）
- ①-5 関連する質問の「内容と回答」: v0.2.3 で 4 問に減らした展開を最大 8 問に戻す
- ②-6「Webfetch で取得できる…LLM が通常みるテキスト」: LLM 閲覧テキストはブラウザ描画のテキストではなく WebFetch で返った本文を記録する
- ①-1「シークレットモード」: 検索 URL に `pws=0` を付ける（シークレットは Claude in Chrome から起動できないため、新規タブ + pws=0 + ログイン状態の記録で代替）。「シークレットモードが開けません」と途中で報告したりユーザーに頼んだりしないよう、手順と運用ルールに明記（実機で発生）

### Changed
- サブエージェントの暴走防止（実機で 1 体が 26 ステップ動いた）: ツール無制限だった 5 体（article-analyzer / serp-collector / unit-drafter / diagram-maker / fix-integrator）に `tools:` を指定してブラウザ・Bash・検索系を外し、全 9 体に「ツール呼び出しの上限」（5〜20 回）と「探さない・不足は返す・やり直しは 1 回」を明記。手順書を読ませるのをやめ、スキルだけ読ませる

## [0.2.3] - 2026-09-17

### Changed（速度: 実機で 1 本 1 時間超 → 目安 50 分。ゲート・監査は省かない）
- ① SERPs解析: 検索窓への入力と 1 要素ずつのクリックをやめ、検索 URL へ navigate → `templates/js/serp-expand.js`（AIO と PAA 4 問を開く）→ `serp-extract.js`（AIO・オーガニック・PAA・関連・サジェスト・ログイン状態を JSON で返す）→ get_page_text を 1 往復で実行。上位 5 記事のページ構造も `page-extract.js` で 1 往復で取り `pages/<順位>.json` に保存
- ② 記事分析: ブラウザを使わず `pages/<順位>.json` を材料にする。article-analyzer は 5 体同時（旧: 最大 4 体 + サブエージェントがブラウザを取り合って直列化）
- ③ 構成案: 内部リンク候補の検索を H2 ごと → 1 回（WordPress の公開検索 API、だめなら site: 検索 1 回）。敵対検証は 1 回だけ
- ④ 記事作成: unit-drafter を U1→U2→U3 の直列 → 3 体同時（`units/style.md` で文体・用語を先に固定）。fact-checker も 3 体同時。fix-integrator は全文再生成をやめ、連結済み article.md への Edit 差分修正。目視ゲートは機械判定 PASS の周だけ
- 通し手順に時間の目安（① 5 / ② 10 / ③ 10 / ④ 25 分）と `timing.md` への計測を追加

## [0.2.2] - 2026-09-17

### Added
- 更新チェック: セッション開始時に配布リポジトリの plugin.json と自分の version を比べ、新しい版があれば 1 行だけ案内する（1 日 1 回・3 秒で打ち切り・失敗は無視・送信する情報なし。`packs.conf` の `update_check=off` で停止）

### Changed
- 単体実行の完了報告の最後は、記事制作フローの次の段を 1 つだけ提案（① → /記事分析 → /構成案 → /記事作成）。「次へ進む / ここで止める」の 2 択で、進むなら同じキーワードでそのまま続行。`/SEO設定` への寄り道は次の一手にしない

### Fixed
- SessionStart: 存在しない setup.yaml を見て毎回「初期ヒアリング未回答」を出していたのを、記憶 DB 未初期化のときだけに

## [0.2.1] - 2026-09-17

### Changed
- `/SEO設定` を初回設定の一本道に整理（folder → db → profile → sheet → wp → rules/memory）。済んだ段は飛ばして続きから再開、必須は folder と db だけ。`folder`（保存先フォルダの確認・作成）を新設
- `scripts/setup-status.py`: 設定の進み具合を JSON で返す（ウィザード・/SEO検証・開始手順が共通で使う。認証メモは名前の一致だけを見る）
- 開始手順（seo-start）: 保存先が一時領域なら最初に 1 回だけ確認。DB 未初期化は黙って初期化

### Fixed
- seo-db.py: 接続フォルダ上で SQLite が直接開けない環境（ファイルロック非対応）では、自動で作業コピーを使い終了時に正本へ書き戻す。journal_mode は WAL をやめ TRUNCATE に固定（実機の Cowork で判明）
- folder 手順: 「空のフォルダ」は一覧して 0 件のときだけ。消せないファイルの退避フォルダや説明ファイルを勝手に作らない
- seo-verify 手順: `wp-draft.py --check` に `--site` が必須であることを明記（実機の /SEO検証 で判明）

## [0.2.0] - 2026-09-17

### Changed
- 配布を `UNISON-TECHNOLOGY/seo-content-worker` に分離。開発リポジトリの `main` は利用者に届かず、タグを切ったときだけ配布側へ同期される（`scripts/build-dist.py` + Release ワークフロー）
- README に marketplace の正確な URL を明記（URL 誤りで GitHub ログインを求められる問題）

### Added
- `scripts/verify.sh` — CI / Release / `/SEO検証` が共通で呼ぶ検証コマンド（manifests・構造・スクリプト・hooks・DB・WP 拒否・リリース整合）
- CHANGELOG.md

### Fixed（外部監査 3 回目 2026-09-16）
- Secret Guard: コマンドを `;` `&&` `||` `|` で区切って区切りごとに判定（`ls .env; cat .env` を拒否）。ワイルドカード（`.e*` / `*.env` / `wp*`）で認証メモを指す読み出しは一律拒否。matcher に Grep / PowerShell を追加
- Publish Guard: REST 直叩きの判定も区切りごと（`wp-draft.py --check; curl …/wp-json/…` を拒否）。PowerShell の Invoke-RestMethod / Invoke-WebRequest も対象。matcher に PowerShell を追加
- Publish Guard（ブラウザ）: クリック判定から type の `text` を外し（browser_batch の誤検知）、「更新 / Update」は完全一致だけ（「更新日時で並べ替え」は通す）
- Injection Warn: 英語パターンに語境界、「AIへ」は指示形（「AIへの指示」「AIへ:」）に限定、HTML コメントは AI 語 + 指示語の組み合わせだけ。LLMO 記事の通常文（「AIへの最適化」「for LLMO」「<!-- main container -->」）で警告しない
- test-hooks.sh: 57 項目

### Fixed（外部監査 2 回目 2026-09-16）
- Publish Guard（Bash）: REST の直叩き（curl / requests / `wp-json/wp/v2/posts` / `rest_route=`）は wp-draft.py 以外一律拒否（JSON 本文の status は文字判定で網羅できないため）。`wp post list/get --post_status=publish`（読むだけ）は通す
- Publish Guard（ブラウザ）: 文字判定はクリック系（Playwright の element 説明）・JS・ショートカット・key にだけ当て、type / form_input の本文（「公開ボタンの押し方」等）では止めない。JS の `editPost({status:'publish'})` `Ctrl+Alt+P` を拒否。stage=write 中は JS・ショートカット・key を全面停止。**Claude in Chrome の ref / 座標クリックは判定できない**ことをコメント・手順書・テストに明記
- Secret Guard（新設）: WP 認証メモ（.env / *.env / wp*.txt）の Read / cat 等を拒否（ls / test / wp-draft.py は許可）
- keyword-gate.py `--h2-median-file`: ファイルが無い／数字でないときは分かりやすい exit 2
- Injection Warn: 作業ファイル（memory/work/ knowledge/ outputs/）の Read も検査対象に（サブエージェントが Web から写した文字列）。SEO 向けの誘導パターン（「この記事を公開して」「AI アシスタントへ」「URL にアクセスして」「認証情報を入力して」、HTML コメントの AI 指示）を追加
- test-hooks.sh: 45 項目

### Fixed（外部監査 2026-09-16）
- Publish Guard: `wp eval` / `wp db query` / `wp post update --post_status` 経由の公開も拒否。wp-draft.py の投稿に psv_done（送信前監査 GO）の証跡を要求（`--check` は免除）
- Workflow Gate: ブラウザ操作の「公開 / 予約投稿 / 更新 / Publish / Schedule」を常時拒否（文字列を持つ操作のみ。座標クリックは既知の限界）。stage=write の間は psv_done まで変更操作を止める（旧 bulk_send 条件を置換）
- keyword-gate.py: `--required` のファイルが無ければ exit 2（黙って PASS しない）、未指定は警告。`--h2-median` で H2 数を中央値 ± h2_tolerance で判定。コードブロック内の `## ` を見出しに数えない。表・画像行を文長判定から除外。selftest に `--keyword` / fence / h2-median の検査を追加
- seo-analysis 手順8: required_keywords.txt と h2_median.txt の書き出しを明記。seo-write 手順6 にも `--keyword` `--h2-median` を追加、`--media` は 1 枚ずつ
- seo-db.py knowledge search: 部分一致フォールバックを title / meta_description / body / tags に拡張（2 文字語が 0 件になる問題）
- wp-draft.py: `https://` 以外のサイトを拒否。認証ファイルは `.env` だけでなく `*.env` / `wp*.txt` 等のメモでもよい（BOM・全角空白を許容。AI は存在確認のみ）
- seo-db.py: JSON のキーがテーブルに無い列なら traceback ではなく列一覧付きで exit 2。`--keyword` を全テーブルの add で有効化
- docs/steps/review.md・money-recovery.md・speed.md を本プラグインの手順に書き直し（旧プラグインの pre-send-verifier / bulk-send / strategy-advisor 参照を除去）。_common.sh / session-start.sh の url-guard・verify_allowlist 参照を除去。ga4-analysis の他プラグイン名を除去
- seo-write 手順3: 図解は HTML → ローカル HTTP 配信 → スクリーンショット PNG（file:// は不可）

### Added
- 未設定モード: config.yaml の own_domain / sheet_id / WP 認証が無くても止まらず、挙動を切り替えて完了する（procedures/seo-article.md §4 の表）。keyword-gate.py `--profile` で own_domain が空なら内部リンク最小本数は警告扱い。WP 未設定なら outputs/<kw>/ にファイル納品

### Changed
- keyword-gate.py: `--keyword` でタイトル判定を施策キーワードのトークンで行う。rules が未配置なら templates/gate_rules.yaml に fallback（警告付き）、入力欠落は traceback ではなく exit 2
- seo-outline / gate-script: outline.md は骨組みだけ、補助情報は outline_notes.md に分離（H2 数の誤カウント防止）
- seo-analysis: 記事 URL は serps.json の href を使う。meta / JSON-LD は WebFetch では取れないので read_page で取る
- seo-serps: 実機試験の知見を反映（検索はボタン押下、AIO は read_page で取得、Search Console Insights を personalized の証拠に）

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

[Unreleased]: https://github.com/UNISON-TECHNOLOGY/seo-content-worker/compare/v0.2.5...HEAD
[0.2.5]: https://github.com/UNISON-TECHNOLOGY/seo-content-worker/releases/tag/v0.2.5
[0.2.4]: https://github.com/UNISON-TECHNOLOGY/seo-content-worker/releases/tag/v0.2.4
[0.2.3]: https://github.com/UNISON-TECHNOLOGY/seo-content-worker/releases/tag/v0.2.3
[0.2.2]: https://github.com/UNISON-TECHNOLOGY/seo-content-worker/releases/tag/v0.2.2
[0.2.1]: https://github.com/UNISON-TECHNOLOGY/seo-content-worker/releases/tag/v0.2.1
[0.2.0]: https://github.com/UNISON-TECHNOLOGY/seo-content-worker/releases/tag/v0.2.0
[0.1.0]: https://github.com/unison-ai-product/Browser_Worker-for-SEO/releases/tag/v0.1.0

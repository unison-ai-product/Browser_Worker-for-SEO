---
description: 標準ワーキング④ 記事作成・公開準備の手順。3ユニット分割の執筆 → 図解の並列生成 → ユニット単位のファクトチェック → レギュレーション統合 → ゲート通過まで修正ループ → WP 下書き投稿とブラウザ確認。公開はしない。
argument-hint: <検索キーワード>
---

# ④ 記事作成・公開準備

**入力**: 承認済みの `memory/work/<kw>/outline.md`（無ければ seo.db `outlines` の最新。承認が無ければ ③ の承認から）。
**規範**: `knowledge/rules/media-rules.md`（装飾・表記・レギュレーション。無ければ /SEO設定 rules で抽出してから）、`skills/seo-writing/SKILL.md`、`skills/diagram-maker/SKILL.md`。

## 手順

**目安 25 分**。速さは並列で稼ぐ（ゲート・ファクトチェック・送信前監査は省かない）。**手順2・3 は 1 メッセージにまとめて同時に起動する**（unit-drafter 3 体 + diagram-maker 最大 4 体）。返りを 1 体ずつ待って次を起動しない。

1. **ユニット分割**: 構成案の H2 を文量で均等に 3 ユニット（U1: リード〜前半 H2 / U2: 中盤 H2 / U3: 後半 H2 + FAQ + まとめ）に割る。各ユニットの「前後の見出し・受け渡す用語・立場（reinforce/oppose/neutral）・必須キーワード・AIO 引用テーマ・内部リンク」を `memory/work/<kw>/units/U<n>.brief.md` に書く。
2. **執筆**: unit-drafter（Sonnet, effort medium）を **U1・U2・U3 の 3 体同時**に起動する。文体・用語を揃えるために、手順1 で `units/style.md`（文体: です・ます / 一人称 / 読者の呼び方 / 用語の統一表 / 数値と出典の書き方 / 各ユニットが冒頭と末尾で受け渡す一文）を書いて 3 体すべてに渡す（前ユニットの本文を待たない。細部の統一は手順5 の fix-integrator が行う）。各体に brief・style.md・media-rules・skills/seo-writing の絶対パスを渡す。出力は `units/U<n>.draft.md`。
3. **図解**: 手順2 と**並列**に diagram-maker（Sonnet）を H2 テーマごと（最大 4 体同時）に起動し、`skills/diagram-maker` の経路 A（HTML/CSS）で `memory/work/<kw>/figures/<h2-slug>.html` + 同名 `.md`（alt / caption / 出典）を作らせる。PNG 化はメインループ: `figures/` を `python -m http.server <port> --bind 127.0.0.1` で配信し、ブラウザで `http://127.0.0.1:<port>/<slug>.html` を開いて `#figure` 要素をスクリーンショット → `figures/<slug>.png`（`file://` は Playwright で拒否される。Playwright の保存先は作業ディレクトリ配下に限られるので、保存後に figures/ へコピーする — 2026-09-16 実測）。終わったらサーバーを止める。経路 B（画像生成 AI）は .prompt.md を受け取ってユーザー指定のサービスで生成する。
4. **ファクトチェック**: 3 ユニットが揃ったら fact-checker（Haiku）を **3 体同時**に起動する（1 体ずつ順に回さない）。数値・固有名詞・法規に触れる断定・AIO と矛盾する記述・出典の無い統計を洗い、`units/U<n>.facts.md` に「要修正（根拠）/ 要出典 / OK」で返させる。要修正は unit-drafter に差し戻し（同じ体を SendMessage で継続）。
5. **統合**: 先にメインループが `cat units/U1.draft.md units/U2.draft.md units/U3.draft.md > article.md` で 1 本に連結する。fix-integrator（Opus, effort medium）には連結済みの article.md + 図解 + facts + media-rules を渡し、**全文を書き直させず Edit で差分修正**させる（全文の再生成は 1 本で数分かかる）。(a) 文体・用語の統一 (b) 装飾ルール（見出し記法・強調・表・箇条書き・引用の書式）の適用 (c) 図解の挿入位置と alt (d) 内部リンクの埋め込み (e) メタディスクリプション・スラッグ案、を行わせて `memory/work/<kw>/article.md` を作る。
6. **ルール＆レギュレーションゲート**（通るまで修正ループ、最大3周）:
   - 機械判定: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/keyword-gate.py --article memory/work/<kw>/article.md --required memory/work/<kw>/required_keywords.txt --keyword "<kw>" --h2-median-file memory/work/<kw>/h2_median.txt --profile knowledge/config/config.yaml --rules knowledge/rules/gate_rules.yaml`（必須KW網羅・施策KW のタイトル判定・禁止語・文字数・見出し数・リンク数・alt 欠落。③ と同じ基準）。
   - 目視判定: keyword-gate（Haiku）に機械判定の結果と記事を渡し、media-rules の各項目を PASS/FAIL で返させる。**機械判定が PASS した周だけ**目視判定に出す（機械判定 FAIL のまま Haiku を呼ばない）。
   - FAIL があれば fix-integrator へ戻す（同じ体を SendMessage で継続し、FAIL 項目だけ Edit で直させる）。3周で通らなければ止めてユーザーに報告（緩めない）。
   - すべて PASS したら証跡を記録（Publish Guard がこれを見る）:
     ```bash
     echo "PASS $(date +%FT%T) rounds=<n>" > memory/.workflow/gate_pass
     ```
7. **送信前監査**: pre-publish-verifier（Haiku）に article.md・outline.md・媒体ルール・WP 投稿計画（タイトル / スラッグ / カテゴリ / 下書き）を渡して VERDICT（GO / NO-GO / UNVERIFIABLE）。GO なら `touch memory/.workflow/psv_done` して次へ（stage=write の間、psv_done が無いとブラウザの変更操作と wp-draft.py の投稿は Workflow Gate / Publish Guard が止める）（**通し /SEO記事 では人の承認を取らない**。下書きなので取り返しが付く）。ブラウザ投稿では JS 実行・ショートカット・key は stage=write 中に使えない（Publish Guard）。貼り付けは form_input、保存は「下書き保存」ボタンのクリックのみ。単体 /記事作成 で呼ばれたときも同じだが、投稿前に VERDICT を 1 画面で報告する。NO-GO / UNVERIFIABLE は投稿せず理由を報告して止まる。
8. **WP 下書き投稿**（どちらか。config.yaml の `wp.method`）。**WP 未設定（認証メモが無い / `wp.site_url` が空）なら投稿せず**、`outputs/<kw>/` に article.html・article.md・meta.md・figures/*.png をコピーして納品し、`echo "NO_POST: WP 未設定（outputs/<kw>/ に納品）" > memory/.workflow/ov_done` で手順9 の代わりとし、手順10 へ進む（psv の VERDICT は取る）:
   - **REST**: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/wp-draft.py --site <site_url> --title "<t>" --content memory/work/<kw>/article.html --status draft [--slug --category --excerpt]`（.env の WP_USER / WP_APP_PASSWORD を読む。値を表示しない）。図解は `--media figures/<slug>.png` を **1 枚ずつ**実行して先にメディアへアップし（glob は受け付けない）、返った URL で本文の参照を差し替える。
   - **ブラウザ**: Claude in Chrome で WP 管理画面 → 投稿 → 新規追加。`knowledge/sites/wordpress.md` の装飾ルール（ブロック / クラシック、使うブロック種）に従って貼り付け、**「下書き保存」のみ**押す。「公開」「予約」は押さない。
9. **ブラウザ確認（REST でも必須）**: 管理画面の投稿一覧（下書きフィルタ）を read_page し、タイトル一致・ステータス「下書き」・更新日時を確認。プレビューを開いて図解の表示と見出し階層を目視。確認できたら:
   ```bash
   echo "VERIFIED draft: <タイトル> id=<post_id>" > memory/.workflow/ov_done
   ```
10. 締め（seo-start 手順7）。完了報告: WP 下書きのタイトル・post_id・プレビュー URL / ゲート周回数 / ファクトチェックの要出典項目（残っていれば） / 図解の枚数。最後に「次の一手」（procedures/seo-article.md §3。④ の次は人間による下書きの確認と公開）を 1 行で示す。記事本文はローカルに残さない（`memory/work/<kw>/` は次回同キーワード開始時に上書きされる一時物）。

## 禁止・注意

- 公開・予約・非公開への変更・既存記事の上書きは AI 不可（Publish Guard が機械拒否。ブラウザでも押さない）。
- 薬機法・医療・金融・法律の断定表現は fact-checker が「要人間判断」で止める。書き換えて通さない。
- 他社記事の文の転用は 60 字以内の引用・出典付きのみ。AIO の言い換え文をそのまま使わない（自社の言葉で「AとはBである」を書く）。

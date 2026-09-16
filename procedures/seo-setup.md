---
description: /SEO設定 の手順。WP 接続・スプレッドシート・自社ドメイン・メディアルール抽出・ユーザーオリジナルメモリ・機能 ON/OFF・SQLite 初期化。ユーザーフィードバックメモリの更新サイクルもここが正本。
argument-hint: [wp / sheet / profile / rules / memory / packs / db / feedback]
---

# /SEO設定

引数が無ければ、未設定の項目を `knowledge/config/config.yaml`（無ければ `templates/config.yaml` を写して作る）から洗い出し、AskUserQuestion で順に埋める。設定はすべてワークスペース側（knowledge/）に置き、プラグイン本体には書かない。

## wp — WordPress 接続

1. サイト URL・投稿方法（rest / browser / both = REST で送りブラウザで確認）・既定カテゴリ・投稿者名を聞いて config.yaml の `wp:` に書く。
2. REST を使う場合: **アプリケーションパスワードはユーザー本人が発行し、ワークスペース直下にテキストファイルとして置く**（AI は値を聞かない・書かない・表示しない・チャットで受け取らない）。ファイル名は `.env` でも `wp.env` `wp-credentials.txt` などでもよい（`.env` / `*.env` / `wp*.txt` / `WP*.txt` / `wordpress*.txt` を順に探し、`WP_APP_PASSWORD=` を含む最初のものを使う）。中身は 2 行:
   ```
   WP_USER=WP のユーザー名
   WP_APP_PASSWORD=WP で発行したアプリケーションパスワード
   ```
   AI が行うのは `ls` での存在確認だけ（`cat` / Read は禁止）。置かれていなければ上の案内文を出して待つ。
3. 接続確認: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/wp-draft.py --site <url> --check`（認証と `posts` 権限の有無だけ返す。投稿はしない）。
4. ブラウザ運用の場合: Claude in Chrome で管理画面を開き（ログインは人間）、投稿画面のエディタ種別・使えるブロック・カテゴリ一覧を read_page で取って `knowledge/sites/wordpress.md` に記録（フェーズ①のマッピング。変更操作はしない）。

## sheet — スプレッドシート

1. 成果物用スプレッドシートの URL（または新規作成の希望）と、キーワードマップのシート（同じファイルの `キーワードマップ` シートか別ファイルか）を聞く。
2. Drive ツールで存在と読み取り可を確認し、`templates/sheet-layout.md` のシート名・ヘッダ行（SERPs / 記事分析 / 構成案 / キーワードマップ）が無ければ作成する（ヘッダ行の追加は変更操作 → seo-start 経由）。
3. config.yaml の `sheet_id` / `keyword_map_sheet` に記録。

## profile — サイトプロファイル（サイト固有の分類・固定見出し・CTA）

スキルは汎用で、サイト固有の語はすべてここに置く（ユーザー決定 2026-09-16）。`templates/site-profile.example.yaml` を Read して項目を把握し、`knowledge/config/site-profile.yaml` を作る。

1. `site`（名前・ドメイン・媒体種別）。
2. `personas`（想定検索者の区分名と区分詳細）と `funnels`（読者層ごとの段階名・区分詳細・属するキーワード語）。ユーザーが持つキーワードマップやカテゴリ表があれば Read して案を提示し、承認を得て書く。無ければ質問ツールで段階を 1 つずつ聞く。
3. `categories`（CV しやすい順の並びと木）と `topics`（メイントピックと中・小分類）。
4. `outline.lead_link`（リード文下「事前に読みたい」を入れるか）と `outline.service_h2`（最終 H2 のサービス訴求。入れないなら null）。
5. `cta`（H2 末尾・H3 内の種別名、テキスト CV リンクの文言、リンク先 URL）。
6. `knowledge/links/priority-articles.csv`（CV している記事: キーワード / タイトル / URL）。既存のスプレッドシートや CSV があれば取り込む。

未定義の項目はスキルが「未定義」と扱い、AI が推測で埋めない。定義後に `/SEO検証` で読めることを確認する。

## rules — メディアルール抽出

`skills/media-rules/SKILL.md` に従い、(a) 既存の自社記事 3 本（WebFetch）から表記・装飾・構成の慣習を抽出、(b) ユーザーが持つレギュレーション文書があれば読み込み、`knowledge/rules/media-rules.md`（人間が読む規範）と `knowledge/rules/gate_rules.yaml`（機械判定できる項目: 禁止語・表記ゆれ・タイトル字数・見出し数・文字数範囲・リンク数）に分けて書く。抽出結果はユーザーに提示して承認を得る。

## memory — ユーザーオリジナルメモリ

`knowledge/memory/original.md` に、自社の主張・一次情報（実測値・事例・顧客の声）・NG な立場・推したい商品/サービスを、ユーザーの言葉で追記する。構成案の手順4 が読む。

## packs — 機能 ON/OFF

`knowledge/config/packs.conf` に `serps=on` `analysis=on` `outline=on` `write=on` `diagram=on` `wp_post=on` を書く。off にした機能は提案も自動発火もしない（SessionStart が通知）。

## db — SQLite 記憶 DB

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/seo-db.py init
```
`knowledge/data/seo.db` を `templates/db-schema.sql` で作る（既存なら追加テーブルのみ）。記録は常に INSERT（追記型）。

## feedback — フィードバックメモリの更新サイクル

1. **ルールフィードバックメモリ**: ユーザーが成果物を直した・評価したら、その場で `knowledge/feedback/lessons.md` に `- YYYY-MM-DD | <ステージ> | <指摘> | <対応>` を 1 行、`seo-db.py feedback add` で 1 行。
2. **アップストリーム**: 同じ指摘が 2 回目（lessons.md を grep）なら、`knowledge/rules/media-rules.md` の該当節へ昇格して 1 行報告。
3. **ゲートスクリプト化**: 昇格したルールが機械判定可能（語・数・有無）なら `gate_rules.yaml` に追加し、`keyword-gate.py --selftest` で判定が効くことを確認。
4. **更新サイクル**: 週 1 回（または /SEO検証 full 時）に lessons.md を読み直し、3 回以上出た指摘で未昇格のものを昇格、矛盾するルールはユーザーに確認。
5. **env 型シークレット**: 認証情報は `.env` のみ。lessons / rules / db に書かない（書かれていたら削除を人間に依頼）。

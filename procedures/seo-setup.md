---
description: /SEO設定 の手順。引数なしは初回設定の一本道（folder → db → profile → sheet → wp → rules/memory）を未完了の段から再開する。個別指定も可。ユーザーフィードバックメモリの更新サイクルもここが正本。
argument-hint: [folder / db / profile / sheet / wp / rules / memory / packs / feedback / status]
---

# /SEO設定

設定はすべてワークスペース側（knowledge/）に置き、プラグイン本体には書かない。値は推測で埋めない。

## 進め方（引数なし = ウィザード）

1. 進み具合を取る（認証メモは名前の一致だけを見る。中身は開かない）:
   ```bash
   python3 ${CLAUDE_PLUGIN_ROOT}/scripts/setup-status.py
   ```
2. 出力の `steps` を次の表の形でそのまま見せ、`next` の段から始める。`done` の段は聞き直さない。

   | 順 | 段 | 必須 | 人の作業 |
   |---|---|---|---|
   | 1 | folder | ○ | 保存先フォルダを選ぶ（1 回） |
   | 2 | db | ○ | なし（自動） |
   | 3 | profile | | 自社ドメイン・想定検索者・カテゴリ・CTA に答える |
   | 4 | sheet | | スプレッドシートの URL を渡す |
   | 5 | wp | | サイト URL と投稿方法に答え、認証メモをフォルダに置く |
   | 6 | rules / memory | | 表記ルールの資料・自社の主張を渡す（後からでよい） |

3. 1・2 が済んだ時点で「ここまでで記事制作は始められます（3〜5 が空の間は未設定モード: シート出力なし・内部リンクは警告扱い・WP 投稿の代わりにファイル納品）」と 1 回だけ伝える。3〜6 は各段の最初に AskUserQuestion で「今やる / あとで」を選べるようにし、「あとで」なら次の段へ進む。
4. 各段の終わりに `setup-status.py` を再実行し、「n/6 完了。残り: …」を 1 行で出す。途中でやめても、次の `/SEO設定` は `next` から再開する。
5. 引数 `status` は 1〜2 だけ行って止まる。引数が段の名前ならその段だけ行う。`packs` `feedback` は運用の項目で、ウィザードには含めない。

## folder — 保存先フォルダ

設定（knowledge/）・記憶 DB・成果物（outputs/）・WP 認証メモを置く場所。未接続のまま進めると一時領域に作られ、セッション終了で消える。

1. `setup-status.py` の `folder` が `done` なら何も聞かず、中身だけ作る:
   ```bash
   mkdir -p memory/.workflow memory/work knowledge/config knowledge/data knowledge/rules knowledge/memory knowledge/feedback knowledge/logs knowledge/links outputs
   touch knowledge/config/.seo-worker   # このフォルダを SEO ワークスペースとして hooks を有効にする印
   [ -f knowledge/config/config.yaml ] || cp ${CLAUDE_PLUGIN_ROOT}/templates/config.yaml knowledge/config/config.yaml
   ```
2. `todo` なら AskUserQuestion で保存先を 1 問で聞く。選択肢は実際に見えているフォルダから作る: (a) 既にある空のフォルダをそのまま使う（推奨）/ (b) その中に専用サブフォルダを新規作成 / (c) ドキュメント直下に新規フォルダ / (d) 保存しない（お試し。設定と記憶はセッション終了で消える）。
   - 「空のフォルダ」と言ってよいのは、実際に一覧してファイルが 0 件だったときだけ（見えていない・数えていないなら「中身は未確認」と書く）。ファイルが 1 件でもあれば (a) は推奨にせず、(b) を推奨にする。
3. (a)〜(c) はフォルダ接続のツールで接続し、接続したフォルダをワークスペースとして 1 の中身を作る。既存の資料が入っているフォルダには混ぜない（(b) を勧める）。接続のツールが無い環境では「Cowork の『フォルダを追加』で空のフォルダを 1 つ選んでください」と案内して待つ。
4. (d) のときは、以後の完了報告に毎回「保存先なし: 設定と記憶はこのセッション限り」を 1 行入れ、成果物は必ずファイルとしてユーザーに渡す。
5. 接続フォルダではファイルの削除・改名ができないことがある。消せないファイルが出ても退避フォルダ（`_to_delete/` 等）を作らず、パスを 1 行で報告するだけにする。説明用のファイル（README 等）を勝手に追加しない。
6. WP 認証メモを置くのもこのフォルダの直下（`wp` の段で案内する）。

## db — SQLite 記憶 DB

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/seo-db.py init
```
`knowledge/data/seo.db` を `templates/db-schema.sql` で作る（既存なら追加テーブルのみ）。記録は常に INSERT（追記型）。

接続フォルダ（ホスト PC の共有フォルダ）の上では SQLite のファイルロックが効かず、直接開けないことがある。その場合は `seo-db.py` が自動で一時領域の作業コピーを使い、終了時に正本（`knowledge/data/seo.db`）へ上書きで書き戻す（`init` の出力が `"mode": "workcopy"`）。**AI が seo.db を手で複製・書き戻ししない**。DB の操作は必ず `seo-db.py` 経由（`sqlite3` コマンドで直接開かない）。

## profile — サイトプロファイル（サイト固有の分類・固定見出し・CTA）

スキルは汎用で、サイト固有の語はすべてここに置く（ユーザー決定 2026-09-16）。`templates/site-profile.example.yaml` を Read して項目を把握し、`knowledge/config/site-profile.yaml` を作る。

1. `site`（名前・ドメイン・媒体種別）。
2. `personas`（想定検索者の区分名と区分詳細）と `funnels`（読者層ごとの段階名・区分詳細・属するキーワード語）。ユーザーが持つキーワードマップやカテゴリ表があれば Read して案を提示し、承認を得て書く。無ければ質問ツールで段階を 1 つずつ聞く。
3. `categories`（CV しやすい順の並びと木）と `topics`（メイントピックと中・小分類）。
4. `outline.lead_link`（リード文下「事前に読みたい」を入れるか）と `outline.service_h2`（最終 H2 のサービス訴求。入れないなら null）。
5. `cta`（H2 末尾・H3 内の種別名、テキスト CV リンクの文言、リンク先 URL）。
6. `knowledge/links/priority-articles.csv`（CV している記事: キーワード / タイトル / URL）。既存のスプレッドシートや CSV があれば取り込む。

未定義の項目はスキルが「未定義」と扱い、AI が推測で埋めない。定義後に `/SEO検証` で読めることを確認する。

## sheet — スプレッドシート

1. 成果物用スプレッドシートの URL（または新規作成の希望）と、キーワードマップのシート（同じファイルの `キーワードマップ` シートか別ファイルか）を聞く。
2. Drive ツールで存在と読み取り可を確認し、`templates/sheet-layout.md` のシート名・ヘッダ行（SERPs / 記事分析 / 構成案 / キーワードマップ）が無ければ作成する（ヘッダ行の追加は変更操作 → seo-start 経由）。
3. config.yaml の `sheet_id` / `keyword_map_sheet` に記録。

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

## rules — メディアルール抽出

`skills/media-rules/SKILL.md` に従い、(a) 既存の自社記事 3 本（WebFetch）から表記・装飾・構成の慣習を抽出、(b) ユーザーが持つレギュレーション文書があれば読み込み、`knowledge/rules/media-rules.md`（人間が読む規範）と `knowledge/rules/gate_rules.yaml`（機械判定できる項目: 禁止語・表記ゆれ・タイトル字数・見出し数・文字数範囲・リンク数）に分けて書く。抽出結果はユーザーに提示して承認を得る。

## memory — ユーザーオリジナルメモリ

`knowledge/memory/original.md` に、自社の主張・一次情報（実測値・事例・顧客の声）・NG な立場・推したい商品/サービスを、ユーザーの言葉で追記する。構成案の手順4 が読む。

## packs — 機能 ON/OFF

`knowledge/config/packs.conf` に `serps=on` `analysis=on` `outline=on` `write=on` `diagram=on` `wp_post=on` を書く。off にした機能は提案も自動発火もしない（SessionStart が通知）。

`update_check=off` を書くと、セッション開始時の更新チェック（配布リポジトリの公開ファイルを 1 日 1 回 GET して新しい版を 1 行で知らせる。送信する情報は無い）を止める。

## feedback — フィードバックメモリの更新サイクル

1. **ルールフィードバックメモリ**: ユーザーが成果物を直した・評価したら、その場で `knowledge/feedback/lessons.md` に `- YYYY-MM-DD | <ステージ> | <指摘> | <対応>` を 1 行、`seo-db.py feedback add` で 1 行。
2. **アップストリーム**: 同じ指摘が 2 回目（lessons.md を grep）なら、`knowledge/rules/media-rules.md` の該当節へ昇格して 1 行報告。
3. **ゲートスクリプト化**: 昇格したルールが機械判定可能（語・数・有無）なら `gate_rules.yaml` に追加し、`keyword-gate.py --selftest` で判定が効くことを確認。
4. **更新サイクル**: 週 1 回（または /SEO検証 full 時）に lessons.md を読み直し、3 回以上出た指摘で未昇格のものを昇格、矛盾するルールはユーザーに確認。
5. **env 型シークレット**: 認証情報は `.env` のみ。lessons / rules / db に書かない（書かれていたら削除を人間に依頼）。

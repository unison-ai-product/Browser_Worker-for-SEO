---
description: ブラウザ変更操作を伴うタスクの開始手続き（ワークフローフラグ初期化 + フェーズ判定）。SERPs解析（検索窓への入力）・WP下書き投稿・スプレッドシートへの書き込みの前に必ず実行する。WebFetch だけの調査では不要。
argument-hint: <タスク名>（例: serps_<キーワード> / write_<キーワード>）
---

SEO Worker のタスク「$ARGUMENTS」を開始する。手順の正本は `docs/steps-reference.md`（迷ったら全文 Read）。

0. 引数からステージを判定する（serps / analysis / outline / write / setup / verify）。通し実行（/SEO記事）ならステージごとに本手順を繰り返さず、**1タスク = 1キーワードの通し**として active を1本にし、ステージ境界では `memory/.workflow/stage` を書き換えるだけにする。

0.5. 環境と能力を確定する:
   - `Bash` / `SendUserFile` があれば cloud（hooks が機械強制）。`mcp__workspace__bash` ならローカル（hooks 未配線＝自己規律のみ）。ローカルなら「ゲートは機械強制されない」と1行伝える。
   - 運用ルールの注入（SessionStart の【SEO Worker 運用ルール】）が文脈に無ければ、プラグインの `hooks/scripts/session-rules.txt` を Read する。
   - `docs/steps/credential.md` を Read（認証フィールドの自己規律。WP ログインは人間が行う）。
   - 使えるブラウザ系統を確認する: `mcp__claude-in-chrome__*` が第一、無ければ `mcp__playwright__*`。両方無ければ ToolSearch で再検索してから判断。
   - Google スプレッドシート連携（Drive の MCP ツール）と `python3`・`sqlite3` の有無を確認し、`knowledge/config/config.yaml` の `sheet_id` / `wp.site_url` / `own_domain` が埋まっているか見る。埋まっていない項目は**未設定モード**として続行する（推測で埋めない。挙動の違いは procedures/seo-article.md §4 の表。完了報告に「未設定: sheet_id / own_domain / wp」のように列挙し、/SEO設定 を案内する）。

0.7. 保存先を確認する: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/setup-status.py` の `folder` が `todo`（一時領域）なら、AskUserQuestion で 1 回だけ「保存先フォルダを接続する（procedures/seo-setup.md の folder）/ 保存せずに続ける」を聞く。保存せずに続ける場合は完了報告に「保存先なし」を 1 行入れ、成果物をファイルで渡す。`done` なら何も聞かない。`db` が `todo` なら `seo-db.py init` を黙って実行する（質問しない）。

1. 作業場とフラグを初期化する:
   ```bash
   mkdir -p memory/.workflow memory/work knowledge/logs knowledge/data knowledge/feedback knowledge/rules knowledge/config
   rm -f memory/.workflow/{b4_done,e_done,k_done,gate_pass,ov_done,psv_done}
   echo "$ARGUMENTS" > memory/.workflow/active
   ```
   （`money_alert` は含めない。解除は docs/steps/money-recovery.md の手順のみ）

2. フェーズを判定して記録する（① 初回: このキーワード・このサイトのナレッジなし / ② 再訪問: ナレッジあり・成功ログなし / ③ 構造変更: 実行中に Google/WP の画面構造がナレッジと不一致 / ④ 最適化: 成功ログ + shortcut_memo あり）:
   ```bash
   echo "1" > memory/.workflow/phase && touch memory/.workflow/b4_done
   ```
   ナレッジの場所: `knowledge/sites/google-search.md`（SERP の要素ランドマーク）、`knowledge/sites/wordpress.md`（WP 管理画面）、`knowledge/keywords/<キーワード>.md`（過去の解析要約）。SQLite の `serp_runs` に同キーワードの行があれば ② 以上。

3. Step E（変更前記録）: 操作対象ページを read_page / get_page_text で**テキスト読取**し（スクショだけは不可）、主要値を `memory/work/<kw>/before.md` に残したら:
   ```bash
   touch memory/.workflow/e_done
   ```
   WP 下書き投稿を含むタスクは、投稿前に WP 管理画面の下書き一覧（件数・最新タイトル）を before として記録する。

4. Step F〜G は各ステージの手順書（seo-serps / seo-analysis / seo-outline / seo-write）に従う。

5. Step H: WP 下書き投稿の直前は pre-publish-verifier（Haiku）の VERDICT が GO であることを確認してから（人の承認は取らない。承認の深さはコマンドが決める — seo-article §2）:
   ```bash
   touch memory/.workflow/psv_done
   ```

6. Step I: 投稿後は WP 管理画面の下書き一覧を read_page し、タイトル一致・ステータス draft を確認してから:
   ```bash
   echo "VERIFIED draft: <タイトル> id=<post_id>" > memory/.workflow/ov_done
   ```
   投稿しなかったタスク（解析・構成案のみ）は `echo "NO_POST: <ステージ>" > memory/.workflow/ov_done`。

7. Step K: `knowledge/logs/<タスク名>_<YYYY-MM-DD>_<HHmm>.md`（docs/steps/logging.md のスキーマ + `keyword` / `stage` / `sheet_rows`）→ `memory/session-log.md` に学び → 最後に:
   ```bash
   touch memory/.workflow/k_done
   ```

8. 実行中に Google / WP の構造差異を検出したらフェーズ③:
   ```bash
   rm -f memory/.workflow/e_done && echo "3" > memory/.workflow/phase
   ```
   `knowledge/sites/*.md` の該当ランドマークを修正してから Step E をやり直す。

9. エラー時: スクリーンショット → 状況報告 → 指示待ち。自動リカバリー禁止。同一失敗2回で adversarial-reviewer に相談。

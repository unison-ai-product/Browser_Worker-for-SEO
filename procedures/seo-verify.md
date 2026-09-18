---
description: /SEO検証 の手順。プラグインのセルフテスト（hooks / 台帳と実体の突合 / 設定充足）と状態確認（残留フラグ・未完了タスク）。
argument-hint: [quick / full]
---

# /SEO検証

## 状態確認（常に）

1. `memory/.workflow/` の `active` / `stage` / `phase` / 各フラグ（b4_done e_done gate_pass psv_done ov_done k_done money_alert）を `ls -la` で一覧し、意味を 1 行ずつ添えて報告。残留（active があり k_done なし）なら「引き継ぐか、ユーザーが中断と判断して `rm -f memory/.workflow/active` するか」を 1 問で聞く（AI が勝手に消さない）。
   hooks の適用範囲も 1 行で報告する: `knowledge/config/.seo-worker`・`knowledge/data/seo.db`・`memory/.workflow/stage` のどれも無ければ「このフォルダでは hooks（ゲート・ガード）が無効。`/SEO設定` か `/SEO記事` で有効になる」（他プロジェクトで hooks を動かさないための仕様）。
2. `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/setup-status.py` を実行し、初回設定の進み具合（folder / db / profile / sheet / wp / rules の 6 段と `n/6`）を表で報告する。`folder` が `todo` なら「保存先フォルダ未接続: 設定と記憶はセッション終了で消える。`/SEO設定` で接続」を表の直後に 1 行で強調する。認証メモは存在だけ（中身は見ない。キー名の一覧も作らない）。`knowledge/data/seo.db` があればテーブルごとの件数（`seo-db.py stats`）。

## quick（既定）

3. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify.sh` を実行し、出力の PASS/FAIL をそのまま表にして報告する（manifests・構造・コマンド→手順書・配役表・スクリプト・hooks・ゲート selftest・SQLite・WP 拒否。CI と同じ内容）。
4. verify.sh が FAIL のときだけ、該当項目を個別に確認して原因を 1 行で添える（プラグイン本体の修正は開発者作業。勝手に直さない）。

## full

5. quick に加えて: `keyword-gate.py --selftest`、`wp-draft.py --site <config.yaml の wp.site_url> --check`（認証メモと wp.site_url の両方があるときのみ。`--site` は必須。投稿はしない）、Drive ツールでスプレッドシートのヘッダ行が `templates/sheet-layout.md` と一致するか、`skills/*/SKILL.md` の frontmatter（name がディレクトリ名と一致）を検査。
6. 疑似実行（E2E は行わない）: テスト用キーワードで ① の抽出定義（skills/seo-analysis）を読み、記事順位の採番ルールを 1 例で説明できるかを自己確認。

## 報告

PASS / FAIL / SKIP の表 + FAIL の修正提案。修正の実施はユーザー承認後（プラグイン本体の編集は開発者作業）。

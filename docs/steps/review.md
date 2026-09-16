# Step H — ゲート・監査・承認の手順（正本）

> **WP 下書き投稿の前にだけ読む**（④ 記事作成の手順6〜7 の補足）。読み取りだけのタスク、投稿の無いタスクでは読まない。

## 1. ルール＆レギュレーションゲート（gate_pass）

- 機械判定 `scripts/keyword-gate.py` と目視判定 keyword-gate（Haiku）の両方 PASS で `echo "PASS <日時> rounds=<n>" > memory/.workflow/gate_pass`（Bash の echo のみ。Write/Edit は Flag Guard が止める）
- 修正ループは最大 3 周（fix-integrator）。通らなければ止めてユーザーに報告。基準を緩めない（例外は gate_rules.yaml をユーザーが編集）
- 本文を変えたら gate_pass は無効。再実行して記録し直す

## 2. 送信前監査（pre-publish-verifier → psv_done）

- WP 下書き投稿の直前に pre-publish-verifier（Haiku）へ article.md・outline.md・媒体ルール・投稿計画（サイト / タイトル / スラッグ / カテゴリ / status=draft / 方法）を渡し VERDICT を取る
- GO のときだけ `touch memory/.workflow/psv_done`。NO-GO / UNVERIFIABLE は投稿せず理由を報告して止まる
- 周回は最大 2（agents/pre-publish-verifier.md「収束条件」）。AUDIT-EXHAUSTED は縮小案を添えて人間へ
- stage=write の間、psv_done が無いとブラウザの変更操作（Workflow Gate）と wp-draft.py の投稿（Publish Guard）は機械的に止まる

## 3. 承認

- 通し（/SEO記事）は WP **下書き**まで人の承認を取らない（取り返しが付くため）。単体 /記事作成 は投稿前に VERDICT を 1 画面で報告する
- **公開・予約・非公開・既存記事の上書きは AI 不可**（Publish Guard が Bash とブラウザ操作の両方で拒否。座標クリックは判定できないので「押すのは下書き保存のみ」を守る）

## 4. 投稿後のブラウザ確認（ov_done）

- REST でも必ず管理画面の投稿一覧（下書き）を read_page し、タイトル・ステータス・更新日時を確認して `echo "VERIFIED draft: <タイトル> id=<post_id>" > memory/.workflow/ov_done`
- ov_done が無いと k_done（タスク完了）は Drop Guard が警告する

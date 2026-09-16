# SEO Worker ステップ正本（A〜K）

> ブラウザ変更操作・WP 投稿・スプレッドシート書き込みを伴うタスクの手順の正本。procedures/seo-start.md はフラグ操作の最短経路のみを書き、方法論はここに一元化する。
> 詳細節は必要なときだけ読む: 不可逆操作 → [steps/cp.md](steps/cp.md) / 承認・監査 → [steps/review.md](steps/review.md) / ナレッジ → [steps/knowledge.md](steps/knowledge.md) / 複数ページ読取 → [steps/speed.md](steps/speed.md) / ログ → [steps/logging.md](steps/logging.md) / 認証 → [steps/credential.md](steps/credential.md) / money_alert → [steps/money-recovery.md](steps/money-recovery.md)。
> （これらは browser-worker プラグインから移植。文中の「スカウト」「一括送出」は本プラグインでは「WP 下書き投稿」「スプレッドシート追記」に読み替える。design-critic / critic_pending は本プラグインに無い。）

## ステップ一覧

| Step | 名称 | 本プラグインでの要点 |
|---|---|---|
| A Order | タスク指令 | キーワード・到達ステージ・投稿方法を確定。不可逆操作（WP 投稿・シート追記）の有無を判定 |
| B Recon | 外部探索 | seo.db 履歴・knowledge/keywords・knowledge/sites を読み、フェーズ判定（B-4） |
| C Probe | 内部探索 | Google SERP / WP 管理画面の構造を read_page で取得しナレッジと照合 |
| D Map | マッピング | 構造ランドマークを knowledge/sites/*.md に記録 |
| E Observe | 変更前記録 | テキスト読取を必ず含める。WP 投稿を含むなら下書き一覧の件数・最新タイトルを before に |
| J Report | 差分比較 | ②③④のみ。前回ログの after_state と今回 before を比較し外部変更を報告 |
| F Plan | 計画 | ステージ手順書に従う。投稿を含むなら CP（成功証跡 = 下書き一覧に該当タイトル・status draft）を宣言 |
| G Act | 実行 | サブエージェントは配役表の役割で。読み取りは 1 コール集約 |
| H Review | 承認 | 構成案はユーザー承認。WP 投稿は pre-publish-verifier VERDICT → 承認 → psv_done |
| I Verify | 検証 | REST 投稿でもブラウザで下書きを確認 → ov_done。ログ記録 → ナレッジ更新 |
| K Offer | 完了 | 完了報告 → session-log → k_done |

## フェーズ判定（B-4）

| # | フェーズ | 条件 |
|---|---|---|
| ① | 初回 | このキーワードの seo.db 履歴なし、または対象サイトのナレッジなし |
| ② | 再訪問 | ナレッジあり、成功ログなし |
| ③ | 構造変更 | 実行中に Google / WP / シートの構造がナレッジと不一致 |
| ④ | 最適化 | 成功ログ + shortcut_memo あり（同キーワードの再解析・リライト） |

③ 発動時: `rm -f memory/.workflow/e_done && echo 3 > memory/.workflow/phase`、ナレッジを直してから E をやり直す。

## 本プラグイン固有のフラグ

| フラグ | 立てる場所 | 見るゲート |
|---|---|---|
| `active` / `phase` / `b4_done` / `e_done` | seo-start 手順1〜3 | Workflow Gate |
| `stage` | 各ステージ開始時 | （報告用） |
| `gate_pass` | seo-write 手順6（ルール＆レギュレーションゲート PASS） | Publish Guard |
| `psv_done` | seo-write 手順7（監査 + 承認） | Workflow Gate（bulk_send 相当） |
| `ov_done` | seo-write 手順9 / 投稿なしは NO_POST | Flag Guard の文言・締めの前提 |
| `k_done` | seo-start 手順7 | Drop Guard / SessionStart |

## エラー処理

スクリーンショット → 報告 → 指示待ち。自動リカバリー禁止。CAPTCHA は突破しない。同一失敗 2 回で adversarial-reviewer に相談。

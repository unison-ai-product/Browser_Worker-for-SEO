# タスク実行ログのスキーマ（Step I で読む）

> `docs/steps-reference.md` から分離（2026-07-27）。**必要なときだけ読む**（内容の移動のみ）。

## I-3. タスク実行ログ記録（必須スキーマ）

`knowledge/logs/<タスク名>_<YYYY-MM-DD>_<HHmm>.md` に **YAML フロントマター付き**で記録する。
フロントマターは B-4 フェーズ判定・/レポート の状況サマリーが機械的に読むため省略禁止:

```yaml
---
task: <タスク名>
site: <サイトキー>
phase: 2            # 1:初回 / 2:再訪問 / 3:構造変更 / 4:最適化
status: success     # success / failed / partial / aborted
started_at: "YYYY-MM-DDTHH:MM:00"
finished_at: "YYYY-MM-DDTHH:MM:00"
steps_completed: [A, B, E, F, G, I, K]
errors: []
before_state: { <E で記録した主要値> }
after_state: { <I で確認した主要値> }
shortcut_memo:      # 次回フェーズ④判定・レシピに使う。無ければ []
  - "<効率ルートのヒント>"
---
```

本文は自由記述: 実行内容 / 変更前→変更後 / 学び / エラー。

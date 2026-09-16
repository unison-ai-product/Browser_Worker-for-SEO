#!/bin/bash
# Flag Guard — ワークフローフラグ（memory/.workflow/）へのファイルツール（Write / Edit）経由の書き込みを止める
# （PreToolUse:Write|Edit|MultiEdit|NotebookEdit）。
# 背景（2026-09-10 横断監査）: OV Gate は Bash の「touch k_done」しか見ていないため、Write ツールで
# memory/.workflow/k_done を直接作れば outcome-verifier の検証なしに完了宣言できた。フラグは各手順が示す
# Bash コマンド（touch / echo）で操作する前提であり、ファイルツールで書く正当な場面はない。
# 対象は memory/.workflow/ 配下だけ。knowledge/ や成果物の Write には一切干渉しない。
# 照合は `memory/` セグメントを含むパス表記が対象（cwd=memory 前提の `.workflow/k_done` のような相対表記は範囲外。cwd はプロジェクトルートが前提）。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# file_path / notebook_path のいずれかが memory/.workflow/ を指すときだけ対象（区切りは / と \ の両方）
# 照合は STDIN_TEXT（\u デコード済み）— \u005c で区切りをエンコードされた file_path も拾う
printf '%s' "$STDIN_TEXT" | grep -qE '"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"[^"]*memory[/\\]+\.workflow[/\\]' || exit 0

MSG="【Flag Guard】memory/.workflow/ 配下のフラグはファイルツール（Write / Edit）では書けません。各手順が示す Bash コマンドで操作してください（k_done は touch memory/.workflow/k_done のみ。ov_done は手順どおり echo で記録）— OV Gate はそのコマンドを見て検証します。k_done は公開後のブラウザ確認記録（ov_done）が揃ってから、psv_done は監査 + 承認が揃ってから。フラグだけ立てる迂回は禁止です。"
SHORT="【Flag Guard】memory/.workflow/ への Write/Edit は不可。Bash の touch / echo で（手順: procedures/seo-start.md）"
gate_emit flag "Flag Guard" "$MSG" "$SHORT"

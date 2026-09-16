#!/bin/bash
# Drop Workflow Guard — Stop hook（警告のみ）
# active があるのに k_done が無いまま応答を終えようとしたら、途中放棄（ドロップ）として注意を注入する。
# ブロックはしない（無限ループ防止）。次の応答で締め（logs → session-log → k_done）を促す。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
if [ -f "$WF_DIR/active" ] && [ ! -f "$WF_DIR/k_done" ]; then
  task="$(head -c 80 "$WF_DIR/active" 2>/dev/null | tr -d '\n"\\')"
  msg="$(json_escape "【Drop Guard】タスク「$task」が締め処理（knowledge/logs → memory/session-log.md → k_done）を終えていません。ユーザーが中断を指示した場合を除き、次の応答で締めを完了してください。途中の成果物（スプレッドシート行・SQLite 記録）は必ず現状のまま保存し、消さないこと。")"
  printf '{"systemMessage":"%s"}' "$msg"
fi
exit 0

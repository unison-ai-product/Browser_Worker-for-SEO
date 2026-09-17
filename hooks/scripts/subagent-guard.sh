#!/bin/bash
# Subagent Guard — PreToolUse:Agent|Task
# 無指定サブエージェントガード: subagent_type がプラグインの配役表（agents/）に無い・または未指定の起動を止める。
# 仕様の3層（Sonnet 実行 / Haiku 検査 / Opus 統合判断）を崩して汎用エージェントに執筆や判断をさせない。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

ROSTER='serp-collector|article-analyzer|outline-builder|unit-drafter|diagram-maker|fact-checker|keyword-gate|pre-publish-verifier|fix-integrator|adversarial-reviewer'
TYPE="$(printf '%s' "$STDIN_TEXT" | sed -n 's/.*"subagent_type":"\([^"]*\)".*/\1/p' | head -1)"

# ワークスペース側の許可（knowledge/config/agent-allowlist.txt に1行1名。ユーザーが編集する）
EXTRA=""
if [ -f "$PROJECT_DIR/knowledge/config/agent-allowlist.txt" ]; then
  EXTRA="$(grep -vE '^[[:space:]]*(#|$)' "$PROJECT_DIR/knowledge/config/agent-allowlist.txt" | tr -d '\r' | tr '\n' '|' | sed 's/|$//')"
fi
[ -n "$EXTRA" ] && ROSTER="$ROSTER|$EXTRA"

if [ -z "$TYPE" ]; then
  gate_emit subagent "Subagent Guard" \
    "【Subagent Guard】subagent_type が未指定です。このプラグインのサブエージェントは配役表（serp-collector / article-analyzer / unit-drafter / diagram-maker = Sonnet 実行、fact-checker / keyword-gate / pre-publish-verifier = Haiku 検査、fix-integrator / adversarial-reviewer = Opus 統合判断）から役割で選んで起動してください。汎用エージェントに執筆・判断をさせることは禁止です。" \
    "【Subagent Guard】subagent_type 未指定。配役表 docs/agent-roster.md"
fi
# プラグイン接頭辞（seo-content-worker:xxx）を剥がして照合
BARE="${TYPE##*:}"
if ! printf '%s' "$BARE" | grep -qxE "($ROSTER)"; then
  gate_emit subagent "Subagent Guard" \
    "【Subagent Guard】「$TYPE」は配役表にありません。docs/agent-roster.md の役割から選び直してください。どうしても別のエージェントが必要なら、ユーザーが knowledge/config/agent-allowlist.txt に名前を追加します（AI が代行編集しない）。" \
    "【Subagent Guard】$TYPE は配役外。docs/agent-roster.md"
fi
exit 0

#!/bin/bash
# Secret Guard — PreToolUse:Read|Bash
# WP 認証メモ（.env / *.env / wp*.txt / WP*.txt / wordpress*.txt）を AI が読むことを機械的に止める。
# 読んでよいのは scripts/wp-draft.py（投稿スクリプト）だけ。存在確認（ls / test -f / [ -f）は許可。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

CRED='(^|[/\\"'"'"' ])(\.env|[^/\\"'"'"' ]*\.env|wp[^/\\"'"'"' ]*\.txt|WP[^/\\"'"'"' ]*\.txt|wordpress[^/\\"'"'"' ]*\.txt)([/\\"'"'"' ]|$)'
MSG="【Secret Guard】WP 認証メモ（.env / wp*.txt など）を AI が読むことは許可されていません。読むのは scripts/wp-draft.py だけです。存在確認は ls / test -f で行ってください。"

# Read / Glob 系: file_path が認証メモを指す
if printf '%s' "$STDIN_TEXT" | grep -qE '"(file_path|path|notebook_path)"[[:space:]]*:[[:space:]]*"[^"]*'"$CRED"; then
  deny "$MSG"
fi

# Bash: 認証メモの名前を含み、かつ許可された形（ls / test / [ -f / wp-draft.py）でないコマンド
CMD="$(printf '%s' "$STDIN_TEXT" | sed -n 's/.*"command":"\(.*\)".*/\1/p' | head -c 20000)"
if [ -n "$CMD" ] && printf '%s' "$CMD" | grep -qE "$CRED"; then
  if ! printf '%s' "$CMD" | grep -qE '^[[:space:]]*(ls|dir|test|\[|stat|wc|file)[[:space:]]' && ! printf '%s' "$CMD" | grep -qE 'wp-draft\.py'; then
    deny "$MSG"
  fi
fi
exit 0

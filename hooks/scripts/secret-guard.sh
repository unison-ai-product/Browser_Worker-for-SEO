#!/bin/bash
# Secret Guard — PreToolUse:Read|Bash
# WP 認証メモ（.env / *.env / wp*.txt / WP*.txt / wordpress*.txt）を AI が読むことを機械的に止める。
# 読んでよいのは scripts/wp-draft.py（投稿スクリプト）だけ。存在確認（ls / test -f / [ -f）は許可。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

CRED='(^|[/\\"'"'"' ])(\.env|[^/\\"'"'"' ]*\.env|wp[^/\\"'"'"' ]*\.txt|WP[^/\\"'"'"' ]*\.txt|wordpress[^/\\"'"'"' ]*\.txt)([/\\"'"'"' ]|$)'
MSG="【Secret Guard】WP 認証メモ（.env / wp*.txt など）を AI が読むことは許可されていません。読むのは scripts/wp-draft.py だけです。存在確認は ls / test -f で行ってください。"

# Read / Glob 系: file_path が認証メモを指す
if printf '%s' "$STDIN_TEXT" | grep -qE '"(file_path|path|notebook_path)"[[:space:]]*:[[:space:]]*"([^"]*[/\])?(\.env|[^"/\]*\.env|wp[^"/\]*\.txt|WP[^"/\]*\.txt|wordpress[^"/\]*\.txt)"'; then
  deny "$MSG"
fi

# Bash / PowerShell: コマンドを ; && || | 改行 で区切り、認証メモに触れる区切りは
# 「先頭が ls / dir / test / [ / stat / wc / file / Test-Path / Get-ChildItem」か「wp-draft.py の呼び出し」のときだけ許可。
# ワイルドカード（.e* / *.env / wp* / *.txt）で名前をぼかした読み出しは一律拒否。
CMD="$(printf '%s' "$STDIN_TEXT" | sed -n 's/.*"command":"\(.*\)".*/\1/p' | head -c 20000)"
if [ -n "$CMD" ]; then
  while IFS= read -r SEG; do
    [ -n "$SEG" ] || continue
    HIT=0
    printf '%s' "$SEG" | grep -qE "$CRED" && HIT=1
    printf '%s' "$SEG" | grep -qiE '(^|[ /\\])(\.e[a-z]*[*?]|[*?]+\.?env\b|wp[a-z0-9_-]*[*?]|[*?]+\.txt\b|wordpress[a-z0-9_-]*[*?])' && HIT=2
    [ "$HIT" = "0" ] && continue
    if [ "$HIT" = "2" ]; then deny "$MSG（ワイルドカードで認証メモを指す読み出しは拒否）"; fi
    if printf '%s' "$SEG" | grep -qE '^[[:space:]]*(ls|dir|test|\[|stat|wc|file|Test-Path|Get-ChildItem|gci)([[:space:]]|$)'; then continue; fi
    if printf '%s' "$SEG" | grep -qE 'wp-draft\.py'; then continue; fi
    deny "$MSG"
  done < <(printf '%s\n' "$CMD" | sed -E 's/(&&|\|\||;|\||\\n)/\n/g')
fi
exit 0

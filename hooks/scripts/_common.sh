#!/bin/bash
# SEO Worker Hook — shared functions (Cowork / Linux VM compatible)
# ワークスペースのパスは CLAUDE_PROJECT_DIR から解決する（絶対パス直書き禁止）

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
WF_DIR="${DELVEWORK_WF_DIR:-$PROJECT_DIR/memory/.workflow}"

# Capture stdin (hook payload JSON) for input inspection
STDIN_JSON="$(cat 2>/dev/null || true)"

# STDIN_TEXT: ツール結果JSONは日本語が \uXXXX エスケープで来ることがあり、そのままでは
# 日本語パターン（決済/クレジットカード等）が一切マッチしない（Money Watch がサイレント無効化）。
# 日本語照合は必ず STDIN_TEXT に対して行うこと。
# v1.15.0: 小さな入力（PreToolUse の tool_input 等、ほぼ全ての hook 呼び出し）は純 bash でデコードし、
# 子プロセスを起動しない（以前は毎回 perl/python を起動しており Windows の test-hooks が5分かかる主因だった）。
# 大きな入力（read_page の結果等）は bash では文字列コピーが効いて遅くなる（実測で超線形）ので、
# 従来どおり perl/python に渡す。外部ツールが無い環境では bash が処理する（上限付き）。
# bash 実装は前方走査（走査済みは out に確定・再走査しない）なので、\u005c の展開結果を再びエスケープと
# 誤認しない。JSON の `\\`（エスケープされたバックスラッシュ）は対で保持し、後続の u.... を展開しない。
# UTF-8 バイト列は自前で組む（bash printf の \u はロケール依存で使えない）。サロゲートペアは合成する。
JSON_BASH_DECODE_MAX="${DELVEWORK_BASH_DECODE_MAX:-2000}"   # この文字数までは bash（実測: 2,000 文字・333 エスケープで約150ms）、超えたら外部ツール
json_unescape_u() { # $1: 文字列 → stdout: \uXXXX を UTF-8 に展開した文字列
  local s="$1" out="" pre hex lo cp ch guard=0
  while [ -n "$s" ]; do
    pre="${s%%\\*}"                       # 次のバックスラッシュまでを確定
    out+="$pre"; s="${s:${#pre}}"
    [ -n "$s" ] || break
    if [ "${s:1:1}" = "u" ] && [[ "${s:2:4}" =~ ^[0-9a-fA-F]{4}$ ]]; then
      hex="${s:2:4}"; s="${s:6}"; cp=$((16#$hex)); lo=""
      if (( cp >= 0xD800 && cp <= 0xDBFF )) && [ "${s:0:1}" = "\\" ] && [ "${s:1:1}" = "u" ] && [[ "${s:2:4}" =~ ^[dD][cdefCDEF][0-9a-fA-F]{2}$ ]]; then
        lo="${s:2:4}"; s="${s:6}"
        cp=$(( 0x10000 + ((cp - 0xD800) << 10) + ($((16#$lo)) - 0xDC00) ))
      fi
      if (( cp < 0x80 )); then
        printf -v ch '\\x%02x' "$cp"
      elif (( cp < 0x800 )); then
        printf -v ch '\\x%02x\\x%02x' $((0xC0 | (cp >> 6))) $((0x80 | (cp & 0x3F)))
      elif (( cp < 0x10000 )); then
        printf -v ch '\\x%02x\\x%02x\\x%02x' $((0xE0 | (cp >> 12))) $((0x80 | ((cp >> 6) & 0x3F))) $((0x80 | (cp & 0x3F)))
      else
        printf -v ch '\\x%02x\\x%02x\\x%02x\\x%02x' $((0xF0 | (cp >> 18))) $((0x80 | ((cp >> 12) & 0x3F))) $((0x80 | ((cp >> 6) & 0x3F))) $((0x80 | (cp & 0x3F)))
      fi
      printf -v ch "$ch"
      out+="$ch"
    elif [ "${s:1:1}" = "\\" ]; then         # JSON の \\ は対で保持（後続の u.... を展開しない）
      out+="${s:0:2}"; s="${s:2}"
    else
      out+="${s:0:1}"; s="${s:1}"
    fi
    guard=$((guard + 1))
    if (( guard > 20000 )); then out+="$s"; break; fi   # 異常に長い入力は残りを生のまま返す（停止性の保証）
  done
  printf '%s' "$out"
}
json_unescape_external() { # 大きな入力向け（従来経路）。成功時 0、外部ツール不在時 1。bash 経路と同じく JSON の \ は対で保持する
  if command -v perl >/dev/null 2>&1; then
    printf '%s' "$1" | perl -CS -pe 's/\\\\/\x00/g; s/\\u([dD][89abAB][0-9a-fA-F]{2})\\u([dD][cdefCDEF][0-9a-fA-F]{2})/chr(0x10000+((hex($1)-0xD800)<<10)+(hex($2)-0xDC00))/ge; s/\\u([0-9a-fA-F]{4})/chr(hex($1))/ge; s/\x00/\\\\/g' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    local PY; PY="$(command -v python3 || command -v python)"
    printf '%s' "$1" | "$PY" -c 'import sys,re
d=sys.stdin.buffer.read().decode("utf-8","surrogateescape").replace("\\\\","\x00")
d=re.sub(r"\\u([dD][89abAB][0-9a-fA-F]{2})\\u([dD][cdefCDEF][0-9a-fA-F]{2})", lambda m: chr(0x10000+((int(m.group(1),16)-0xD800)<<10)+(int(m.group(2),16)-0xDC00)), d)
d=re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1),16)), d)
sys.stdout.buffer.write(d.replace("\x00","\\\\").encode("utf-8","surrogateescape"))' 2>/dev/null
  else
    return 1
  fi
}
if [ "${#STDIN_JSON}" -le "$JSON_BASH_DECODE_MAX" ]; then
  STDIN_TEXT="$(json_unescape_u "$STDIN_JSON")"
else
  STDIN_TEXT="$(json_unescape_external "$STDIN_JSON")" || STDIN_TEXT="$(json_unescape_u "$STDIN_JSON")"
fi
[ -n "$STDIN_TEXT" ] || STDIN_TEXT="$STDIN_JSON"

# JSON文字列へ埋め込む値のエスケープ（ページ/URL由来文字列で hook 出力JSONが壊れる=フェイルオープンを防ぐ）
json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\000-\037'
}

deny() {
  local msg; msg="$(json_escape "$1")"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$msg"
  exit 0
}

# --- deny 文言の減衰（2026-07-28 コンテキスト管理監査） ---
# 停止フラグが残っている間、同じ長文 deny を毎ツールコール再送すると
# コンテキストが理由文で埋まる（1回で伝わる情報を N 回払う）。
# 同一理由の deny が DENY_FULL_MAX 回を超えたら、以降は1行の短縮版だけ返す。
# カウンタは $WF_DIR/.deny_<reason>。理由が変わったら他の理由のカウンタを消す（=リセット）。
# フラグ解除でゲートを通り抜けたときは deny_reset で全カウンタを消す。
# session-start.sh も起動時に消す（セッションをまたいで減衰状態を持ち越さない）。
DENY_FULL_MAX="${DELVEWORK_DENY_FULL_MAX:-2}"

deny_reset() {
  rm -f "$WF_DIR"/.deny_* 2>/dev/null
  return 0
}

deny_decay() { # $1: 理由コード（英数_）, $2: フル文言, $3: 短縮文言（1行・省略可）
  # 自己診断への導線（escalations E5: 文脈喪失後でも deny 1回で /状態確認 に自走できる）は
  # ここで一律に付ける（各ゲートの文言に書かない — 8箇所で同文を繰り返していた乖離リスクの解消）
  local reason="$1" full="$2${STATUS_HINT_FULL}" short="$3" f other cnt=1
  # 短縮文言のない理由（RM Guard 等）は減衰しないので、カウンタに一切触らない
  # （他ゲートの減衰中に rm を挟むと money 等の減衰が巻き戻る、を防ぐ — PR #5 Opus 指摘）
  if [ -z "$short" ]; then deny "$full"; return; fi
  short="${short}${STATUS_HINT_SHORT}"
  mkdir -p "$WF_DIR" 2>/dev/null
  f="$WF_DIR/.deny_$reason"
  for other in "$WF_DIR"/.deny_*; do
    [ -e "$other" ] || continue
    [ "$other" = "$f" ] || rm -f "$other" 2>/dev/null
  done
  if [ -f "$f" ]; then
    cnt="$(head -c 8 "$f" 2>/dev/null | tr -dc '0-9')"
    [ -n "$cnt" ] || cnt=0
    cnt=$((cnt + 1))
  fi
  printf '%s' "$cnt" > "$f" 2>/dev/null
  if [ "$cnt" -gt "$DENY_FULL_MAX" ] && [ -n "$short" ]; then
    deny "$short"
  else
    deny "$full"
  fi
}

# --- 段階導入ゲート（critic / ov / rm）の共通出口 ---
# GATE_MODE=deny（既定）なら deny_decay、warn なら additionalContext で「本来ブロック」を注入して通す。
# 3本のゲートが同型の if/else を各自持っていたのを1関数にまとめた（v1.15.2）。
GATE_MODE="${DELVEWORK_GATE_MODE:-deny}"
STATUS_HINT_FULL="現状が不明なら /SEO検証 で一覧できます。"
STATUS_HINT_SHORT=" ／現状: /状態確認。"  # 先頭スペースで連結（各ゲートの SHORT に末尾スペースを持たせない）
gate_emit() { # $1: 理由コード, $2: ラベル（例: OV Gate）, $3: フル文言, $4: 短縮文言（省略可）
  if [ "$GATE_MODE" = "deny" ]; then
    deny_decay "$1" "$3" "${4:-}"
  else
    warn_pretool "【$2・試運転(warn)】本来ここでブロックされる操作です — $3${STATUS_HINT_FULL}"
  fi
}

warn_pretool() {
  local msg; msg="$(json_escape "$1")"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}' "$msg"
  exit 0
}

warn_posttool() {
  local msg; msg="$(json_escape "$1")"
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}' "$msg"
  exit 0
}

warn_session() {
  local msg; msg="$(json_escape "$1")"
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' "$msg"
  exit 0
}

# --- Money Watch 共通照合（money-watch.sh の PostToolUse と workflow-gate.sh の操作直前判定で共用） ---
# money_suppressed <text>: knowledge/config/money-suppress.txt のパターンに当たれば 0（検知対象外）。
# 抑制は【弱】専用の誤検知チューニング。**強判定には効かせない（ページ読み取り・操作直前とも）**
# （ユーザー編集可能ファイルが硬いゲートの無効化スイッチにならないように — 2026-09-10 レビュー指摘）
money_suppressed() {
  local text="$1" SUPPRESS="$PROJECT_DIR/knowledge/config/money-suppress.txt" pat
  [ -f "$SUPPRESS" ] || return 1
  while IFS= read -r pat; do
    case "$pat" in ''|'#'*) continue ;; esac
    if printf '%s' "$text" | grep -qiE "$pat" 2>/dev/null; then return 0; fi
  done < "$SUPPRESS"
  return 1
}

# list_match <text> <list files...>: コメント・空行を除いた各行を大文字小文字無視の ERE として照合し、
# 最初にマッチしたパターンを stdout に返す（無ければ戻り値1）。bash の [[ =~ ]] を使い外部プロセスを起動しない
# （v1.15.0: 以前はパターンごとに grep を起動しており、1 hook 呼び出しで最大20プロセスだった）。
# grep は行単位で照合するため、[^0-9]{0,10} のような否定括弧式が行を跨いで当たることはない。同じ挙動を
# 保つため、全文で当たったパターンだけ行単位で再確認する（アンカーを含まないパターンでは全文一致が行一致の
# 上位集合なので前段フィルタになる。^ / $ を含むパターンはフィルタせず行単位のみ）。不正な正規表現は grep 版と
# 同じく「不一致」扱いだが、気付けるよう stderr に1回だけ警告する。
# url-guard と Money Watch の両方がこれを使う（ワークスペース側リストとの2層構造も同じ関数で扱う）。
list_match() {
  local text="$1" LIST pat line hit rc; shift
  local had_nc=0; shopt -q nocasematch && had_nc=1; shopt -s nocasematch
  for LIST in "$@"; do
    [ -f "$LIST" ] || continue
    while IFS= read -r pat; do
      case "$pat" in ''|'#'*) continue ;; esac
      # 前段フィルタ（全文一致）は「アンカーを含まないパターンに限り」行一致の上位集合。
      # ^ / $ を含むパターンは全文では行頭・行末に当たらないので、フィルタを飛ばして行単位のみで判定する
      case "$pat" in
        *'^'*|*'$'*) ;;
        *) [[ $text =~ $pat ]]; rc=$?
           if [ "$rc" -eq 2 ]; then
             [ -n "${LIST_MATCH_WARNED:-}" ] || { printf 'SEO Worker: 正規表現として不正なパターンを無視しました（%s: %s）
' "$LIST" "$pat" >&2; LIST_MATCH_WARNED=1; }
             continue
           fi
           [ "$rc" -eq 0 ] || continue ;;
      esac
      hit=0
      while IFS= read -r line; do
        if [[ $line =~ $pat ]]; then hit=1; break; fi
      done <<< "$text"
      if [ "$hit" = 1 ]; then
        (( had_nc )) || shopt -u nocasematch
        printf '%s' "$pat"; return 0
      fi
    done < "$LIST"
  done
  (( had_nc )) || shopt -u nocasematch
  return 1
}
# money_match_lists は後方互換の別名（照合は \uXXXX デコード済みテキストに対して行う）
money_match_lists() { list_match "$@"; }
money_strong() { money_match_lists "$1" "$SCRIPT_DIR/money-watchlist.txt" "$PROJECT_DIR/knowledge/config/money-watchlist.txt"; }
money_weak()   { money_match_lists "$1" "$SCRIPT_DIR/money-watchlist-weak.txt" "$PROJECT_DIR/knowledge/config/money-watchlist-weak.txt"; }

# 【弱】の再警告抑止: 同じ「ページURL × パターン」は1回だけ警告する。
# サイドメニューに「プラン変更」が常在する管理画面（xserver 等）で、読み取りのたびに同文の警告が出ると
# 注意が薄れて実際の金銭操作と区別がつかなくなる（2026-09-10 フィードバック）。
# キーは読み取り結果から拾った最初の URL（無ければパターンのみ）。サイドメニュークリック等の
# navigate を通らない遷移でも URL が変われば再警告される。navigate / SessionStart では全消去。
# ファイルは末尾 50 行に刈り取る（追記のみで肥大しないように）。
WEAK_SEEN="$WF_DIR/.money_weak_seen"
money_weak_seen_reset() { rm -f "$WEAK_SEEN" 2>/dev/null; return 0; }
money_weak_key() { # $1: パターン。stdout: "<url>	<pattern>"
  local url; url="$(printf '%s' "$STDIN_TEXT" | grep -oE 'https?://[^"[:space:]\]+' 2>/dev/null | head -n 1)"
  printf '%s	%s' "$url" "$1"
}
money_weak_seen() { [ -f "$WEAK_SEEN" ] && grep -qxF -- "$1" "$WEAK_SEEN" 2>/dev/null; }
money_weak_mark() {
  mkdir -p "$WF_DIR" 2>/dev/null
  printf '%s
' "$1" >> "$WEAK_SEEN" 2>/dev/null
  if [ "$(wc -l < "$WEAK_SEEN" 2>/dev/null | tr -dc '0-9')" -gt 50 ] 2>/dev/null; then
    tail -n 50 "$WEAK_SEEN" > "$WEAK_SEEN.tmp" 2>/dev/null && mv -f "$WEAK_SEEN.tmp" "$WEAK_SEEN" 2>/dev/null
  fi
  return 0
}


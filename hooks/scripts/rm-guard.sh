#!/bin/bash
# RM Guard — 一括・再帰削除の機械ガード（PreToolUse:Bash）
# 背景: 2026-07-24 ローカル検証で Sonnet・Opus の両方が「後片付け」を拡大解釈し outputs フォルダの
# 一括削除を提案（harness の許可プロンプトで停止）。モデル差でなく指示解釈の構造問題のため機械強制する。判断はエージェント・強制は hook の原則に従い、
# 再帰削除（rm -r）・グロブ一括削除（rm *）・find -delete・git clean を機械層で止める。
# 個別ファイルの rm と memory/.workflow/ 配下のフラグ掃除には干渉しない。
# 導入手順（昇格の記録は TESTING-archive.md「GATE_MODE 昇格」/ 切替の手順は TESTING.md 検証プロンプト (9) の注記）: 初期は warn（注入のみ）で運用し、誤爆ゼロ確認後に deny へ昇格。
# 2026-07-24 deny 昇格済み（v1.1.5 実機2ランで warn 発火・正当な個別削除の誤爆ゼロを確認。V39 実測）。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# --- 照合対象の絞り込み（v1.18.1: V39(b) 誤爆の修正。Opus レビュー6回の経緯は TESTING-archive.md） ---
# 旧実装は hook ペイロード JSON 全文を照合していたため、「再帰削除が deny された」等の説明文を
# ヒアドキュメントで文書に書き出す Bash が、削除を一切していないのに deny された。
# 実行されるコマンド位置とデータとして渡される文章を分ける（単一 command 前提）:
#   1. tool_input.command だけを取り出す（取れなければ全文 = fail-closed）
#   2. bash の字句規則（' / " / \ / # / <<）を1本の走査（rm_guard_scan）で追い、3通りの写しを作る:
#      text  = 照合用。クォート付きデリミタのヒアドキュメント本文（<<'EOF'）は展開されないので落とし、
#              クォート無しの本文は $(...) / ` を含む行だけ残す。空白を含まないクォート（'rm' -rf 等の
#              分割）と英数字前の \（\rm）は外して中身を照合に出す。コメントは捨てる
#      mask  = 分類用。クォート span とエスケープを空白に潰した写し（クォート内の ; や改行で段落が割れない）
#      strip = 出力系コマンド限定の照合用。クォート span（文章）を丸ごと落とす
#      終端行が無いヒアドキュメント・閉じていないクォートは解析失敗として本文を戻す／写しを使わない（fail-closed）。
#      3写しは同じ走査から作るので、クォートのペアリングが食い違って実コマンドが消えることはない（Opus 再レビュー C-B）
#   3. strip は、コマンドが「出力系のみ」（echo / printf / cat / tee / true / : 等の連結）で構成され、
#      $( ) / ` / プロセス置換を含まないときだけ使う。それ以外（bash -c / eval / awk / find -exec /
#      未知の実行語）は文字列を再実行し得るので text で照合する（allowlist 方式）
rm_guard_json_unescape() { # $1: JSON 文字列本体（\uXXXX は _common.sh で展開済み）→ stdout。左から1回走査なので「エスケープ済み \ + n」を改行に誤展開しない
  local s="$1" out="" pre
  while [ -n "$s" ]; do
    pre="${s%%\\*}"; out+="$pre"; s="${s:${#pre}}"
    [ -n "$s" ] || break
    case "${s:1:1}" in
      n) out+=$'\n' ;; t) out+=$'\t' ;; r) ;; '"') out+='"' ;; /) out+='/' ;; \\) out+='\' ;;
      *) out+="${s:0:2}" ;;
    esac
    s="${s:2}"
  done
  printf '%s' "$out"
}
rm_guard_extract_command() { # STDIN_TEXT → stdout: command フィールド。無ければ戻り値1
  local pat='"command":"((\\.|[^"\\])*)"'
  [[ $STDIN_TEXT =~ $pat ]] || return 1
  rm_guard_json_unescape "${BASH_REMATCH[1]}"
}
rm_guard_scan() { # $1: text|mask|strip、stdin → stdout。閉じていないクォートは戻り値1（出力なし）
  awk -v mode="$1" '
    BEGIN { q = sprintf("%c", 39); s = "" }
    { s = s $0 "\n" }
    END {
      n = length(s); out = ""; npend = 0; hd = 0; nbuf = 0; i = 1; wb = 1   # wb: 語境界（# をコメントと見るか）
      while (i <= n) {
        if (hd) {                                            # ヒアドキュメント本文: 1行ずつ終端と比較
          j = index(substr(s, i), "\n"); if (j == 0) j = n - i + 2
          line = substr(s, i, j - 1); i += j
          cmp = line; sub(/\r$/, "", cmp); if (hdash[hi]) sub(/^[ \t]+/, "", cmp)
          if (cmp == hdelim[hi]) { hi++; if (hi >= npend) { hd = 0; npend = 0 }; continue }
          buf[nbuf++] = line                                 # 終端が来なければ末尾で戻す
          if (!hquoted[hi] && mode != "mask" && (line ~ /\$\(/ || index(line, "`"))) out = out line "\n"
          continue
        }
        c = substr(s, i, 1)
        if (c == "\n") { out = out c; i++; wb = 1; if (npend) { hd = 1; hi = 0; nbuf = 0 }; continue }
        if (c == "\\") {                                     # \x は次の1文字をリテラル化（\+改行は行継続 = 何も出さない）
          d = substr(s, i + 1, 1); i += 2; wb = 0; escp = 1   # escp: 直前の文字はエスケープ済み（\$'…' は ANSI-C でない）
          if (d == "\n") continue
          if (mode == "mask") out = out "  "; else if (d ~ /[A-Za-z0-9]/) out = out d; else out = out c d
          continue
        }
        if (c == q || c == "\"") {                           # クォート span（複数行可。" と $'…' の中では \ がエスケープ）
          esc = (c == "\"" || (substr(s, i - 1, 1) == "$" && !escp)); escp = 0
          j = i + 1
          while (j <= n) { e = substr(s, j, 1); if (e == c) break; if (esc && e == "\\") j++; j++ }
          if (j > n) exit 1                                  # 閉じていない = 解析失敗（fail-closed）
          span = substr(s, i, j - i + 1); body = substr(s, i + 1, j - i - 1); i = j + 1; wb = 0
          if (c == q && mode == "text") { gsub(/\$\(/, "$ ", span); gsub(/`/, " ", span); gsub(/\$\(/, "$ ", body); gsub(/`/, " ", body) }   # シングルクォート内は展開されない
          if (mode == "mask") { g = span; gsub(/[^\n]/, " ", g); out = out g }
          else if (mode == "strip") out = out " "
          else if (body ~ /[ \t\n]/) out = out span
          else out = out body                                # 空白を含まないクォートは記号だけ外す
          continue
        }
        if (c == "#" && wb) {                                # 語境界の # はコメント: 改行まで捨てる（foo\ #x の # は語の一部）
          j = index(substr(s, i), "\n"); if (j == 0) j = n - i + 2
          i += j - 1; continue
        }
        if (c == "<" && substr(s, i + 1, 1) == "<" && substr(s, i + 2, 1) != "<" && substr(s, i - 1, 1) != "<") {
          j = i + 2; dash = 0; if (substr(s, j, 1) == "-") { dash = 1; j++ }
          while (substr(s, j, 1) ~ /[ \t]/) j++
          qc = ""; quoted = 0; e = substr(s, j, 1)
          if (e == "\\") { quoted = 1; j++ } else if (e == q || e == "\"") { quoted = 1; qc = e; j++ }
          if (match(substr(s, j), /^[A-Za-z_][A-Za-z0-9_]*/)) {
            delim = substr(s, j, RLENGTH); j += RLENGTH
            if (qc != "" && substr(s, j, 1) == qc) j++
            if (j > n || substr(s, j, 1) ~ /[ \t\n;&|<>]/) {   # 直後が語の終わりのときだけヒアドキュメント（$((1 << x)) は除外）
              hdelim[npend] = delim; hquoted[npend] = quoted; hdash[npend] = dash; npend++
              out = out substr(s, i, j - i); i = j; wb = 0; continue
            }
          }
        }
        wb = (c ~ /[ \t;&|(]/); escp = 0
        out = out c; i++
      }
      if (hd) for (k = 0; k < nbuf; k++) out = out buf[k] "\n"   # 終端が来なかった本文は全部戻す
      printf "%s", out
    }'
}
rm_guard_output_only() { # $1: 生コマンド → 0 なら全セグメントの先頭語が出力系のみ
  # allowlist の条件は「引数文字列をコマンドとして再実行しない語」であること（tee は引数ファイルを切り詰めるが再実行はしない）。
  # 追加時は -exec / -c / sh -c 相当のオプションを持たない語に限る（find / env / watch / xargs は不可）。
  # 分類は mask 写し（クォート span を空白に潰したもの）で行う。走査失敗（未閉クォート）は出力系でない扱い
  local seg first probe redir='^[0-9]*(>>?|<<?)(&[^[:space:]]*|[[:space:]]*[^[:space:]]*)[[:space:]]*'   # >f / >> f / 2>&1 / 9>&2（& 分割で残る裸の 2> も含む）   # $( ) / ` / プロセス置換の有無は呼び出し側が text 写しで判定済み
  probe="$(printf '%s\n' "$1" | rm_guard_scan mask)" || return 1
  probe="$(printf '%s' "$probe" | tr ';|&(){}' '\n\n\n\n\n\n\n')"
  while IFS= read -r seg; do
    seg="${seg#"${seg%%[![:space:]]*}"}"
    [ -n "$seg" ] || continue                                # 空セグメントは && / || / ;; 分割の副産物
    [[ $seg =~ ^[0-9]+$ ]] && continue                      # 2>&1 の「1」（& 分割の残り）
    [[ $seg =~ ^[0-9]+[[:space:]]+ ]] && seg="${seg:${#BASH_REMATCH[0]}}"
    while :; do                                              # 先頭のリダイレクト指定と変数代入だけを剥がし、残った先頭語は必ず検査する
      if [[ $seg =~ $redir ]]; then seg="${seg:${#BASH_REMATCH[0]}}"; continue; fi   # （セグメントごと飛ばすと 2>/dev/null bash -c '…' が無検査になる — Opus 5回目 C-D）
      if [[ $seg =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+ ]]; then seg="${seg:${#BASH_REMATCH[0]}}"; continue; fi
      break
    done
    [ -n "$seg" ] || continue
    first="${seg%%[[:space:]]*}"
    case "$first" in echo|printf|cat|tee|true|:|ls|wc|head|tail|date|pwd) ;; *) return 1 ;; esac
  done <<< "$probe"
  return 0
}
EXTRACTED=1
RAW_CMD="$(rm_guard_extract_command)" || { RAW_CMD="$STDIN_TEXT"; EXTRACTED=0; }   # 取れなければ全文を未加工で照合
CMD_TEXT="$RAW_CMD"
if [ "$EXTRACTED" = 1 ] && [ "${#RAW_CMD}" -le 100000 ] && command -v awk >/dev/null 2>&1; then   # 長大なコマンドは走査せず未加工で照合
  # 3写しはすべて生コマンド RAW_CMD から作る（加工済みテキストを再走査するとクォートのペアリングがずれる）
  if t="$(printf '%s\n' "$RAW_CMD" | rm_guard_scan text)" && [ -n "$t" ]; then
    CMD_TEXT="$t"
    if ! printf '%s' "$CMD_TEXT" | grep -qE '\$\(|`|[<>]\(' && rm_guard_output_only "$RAW_CMD"; then
      t="$(printf '%s\n' "$RAW_CMD" | rm_guard_scan strip)" && [ -n "$t" ] && CMD_TEXT="$t"   # 出力系のみ: 文章を落とす
    fi
  fi                                   # 走査失敗・awk 異常終了（空）なら未加工のまま（fail-closed）
fi

# 対象コマンド判定（該当しなければ即通過）
# 照合は CMD_TEXT と「クォート記号を全削除した写し」の両方に対して行い、どちらかで当たれば対象
# （rm' '-rf のような空白入りクォートでの分割を塞ぐ。写しは内容を隠す方向に働かない。.workflow 免除は CMD_TEXT で判定）
MATCH_TEXT="$CMD_TEXT"$'\n'"$(printf '%s' "$CMD_TEXT" | tr -d "'\"")"
DANGEROUS=0
# rm の再帰フラグ（-r/-R/--recursive、-rf 等の複合も拾う）
if printf '%s' "$MATCH_TEXT" | grep -qE '(^|[^[:alnum:]_-])rm[[:space:]]+(-[[:alnum:]]*[rR]|--recursive)'; then
  DANGEROUS=1
# rm のグロブ一括（rm ... * / rm dir/*.png 等）
elif printf '%s' "$MATCH_TEXT" | grep -qE '(^|[^[:alnum:]_-])rm[[:space:]][^;|&]*\*'; then
  DANGEROUS=1
# find -delete / git clean / PowerShell Remove-Item -Recurse
elif printf '%s' "$MATCH_TEXT" | grep -qE '(^|[^[:alnum:]_-])find[[:space:]][^;|&]*-delete'; then
  DANGEROUS=1
elif printf '%s' "$MATCH_TEXT" | grep -qE '(^|[^[:alnum:]_-])git[[:space:]]+clean'; then
  DANGEROUS=1
elif printf '%s' "$MATCH_TEXT" | grep -qiE 'remove-item[^;|&]*-recurse'; then
  DANGEROUS=1
fi
[ "$DANGEROUS" = "1" ] || exit 0

# 免除: memory/.workflow/ 配下のみを対象とするフラグ掃除（再帰フラグなし）は素通し
# 例: rm -f memory/.workflow/{b4_done,e_done} / rm memory/.workflow/verify_*
if printf '%s' "$CMD_TEXT" | grep -q 'memory/\.workflow/' && \
   ! printf '%s' "$CMD_TEXT" | grep -qE '(^|[^[:alnum:]_-])rm[[:space:]]+(-[[:alnum:]]*[rR]|--recursive)'; then
  # rm の対象パスが .workflow 以外を含まないことを確認（含む場合はゲート対象）
  if ! printf '%s' "$CMD_TEXT" | sed 's|memory/\.workflow/[^[:space:]]*||g' | grep -qE '(^|[^[:alnum:]_-])rm[[:space:]][^;|&]*[[:alnum:]/*]'; then
    exit 0
  fi
fi

# deny 時は「実行可能な出口」まで書く。承認を求めるだけの文言だと、ユーザーが承認しても
# hook は依然 deny のため AI が「承認 → やはり実行できない」を往復して進まない（2026-07-27 過剰ゲート監査）。
MSG="【RM Guard】一括・再帰削除は機械ガード対象です。出口は2つ: (1) 自分が作成したファイルのパスを列挙し、個別に rm する（推奨。1コマンドに複数パスを並べるのは可、グロブ・-r は不可）。(2) どうしてもフォルダごと・グロブで消す必要がある場合は、実行しようとしたコマンドをそのままユーザーに提示し、ユーザー自身の手で実行してもらう。**AI 側で再試行・分割・別手段での回避を試みないこと**。削除できないまま終わる場合は、残置したパスを報告して完了してよい（削除の失敗はタスクの失敗ではない）。削除手順の**文書化**が目的ならクォート付きヒアドキュメントで書けます。"
gate_emit rm "RM Guard" "$MSG"

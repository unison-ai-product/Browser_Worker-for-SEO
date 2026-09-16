#!/bin/bash
# SEO Worker Workflow Gate — PreToolUse hook
# ブラウザ変更操作（click/type/fill_form/select_option/file_upload/press_key）を
# B-4（フェーズ判定）と E（変更前記録）の完了フラグなしではブロックする。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# Credential Guard: パスワード/認証情報フィールドへの「入力」を常時ブロック（フラグの有無に関係なく）
# 対象は入力系操作のみ（form_input / playwright type・fill / computer の type・key）。
# クリックやスクショは対象外（「パスワードをお忘れですか」リンクのクリック等を誤爆させない）
IS_INPUT_OP=0
# browser_network_request（任意 HTTP 送信）: method が明示の GET/HEAD で body 系キーが無いものだけ読み取りと見なす。
# method 省略（既定 GET）は判定不能としてゲートを通す（省略で抜けられる穴を作らない）。GET でも状態変更する API
# （?action=unsubscribe 等）は残存リスク — url-guard と Money Watch が別途止める（2026-09-10 PR #9）。
NR_READONLY=0
if printf '%s' "$STDIN_JSON" | grep -q 'browser_network_request'; then
  if printf '%s' "$STDIN_JSON" | grep -qE '"method"[[:space:]]*:[[:space:]]*"(GET|HEAD|get|head)"' && \
     ! printf '%s' "$STDIN_JSON" | grep -qE '"(body|data|postData|json|form)"[[:space:]]*:'; then
    NR_READONLY=1
  else
    IS_INPUT_OP=1   # 送信を伴う HTTP は入力系として Credential Guard の対象にする
  fi
fi
if printf '%s' "$STDIN_JSON" | grep -qE '(form_input|browser_type|browser_fill_form)'; then
  IS_INPUT_OP=1
elif printf '%s' "$STDIN_JSON" | grep -q 'claude-in-chrome__computer' && \
     printf '%s' "$STDIN_JSON" | grep -qE '"action"[[:space:]]*:[[:space:]]*"(type|key)"'; then
  IS_INPUT_OP=1
fi
if [ "$IS_INPUT_OP" = "1" ] && printf '%s' "$STDIN_TEXT" | grep -qiE '(password|passwd|パスワード|暗証|otp|verification.?code|認証コード|secret|credential)'; then
  deny "【Credential Guard】パスワード・認証情報フィールドへの入力はAIには許可されていません。ログイン・認証入力は人間が行ってください（ブラウザのパスワードマネージャ推奨）。完了したら操作を再開します。"
fi

# Read-only pass-through（意図した順序: 読み取り専用操作は Money Watch 停止中も許可する —
# 状況確認の読取まで止めると復帰手順自体が実行不能になるため。変更系はこの下で money_alert を検査）
# In Chrome の computer ツールは読み取り操作（screenshot/scroll等）も
# 同じツール名で来るため、action を見て変更を伴わない操作は素通しする
# 素通し条件: 読み取り action が含まれる「かつ」変更系 action が一切含まれないこと。
# batch/複合ペイロードで screenshot と click が同梱された場合の誤素通しを防ぐ。
# key（PageDown/End 等）は緩めない — text 内容で読み取り扱いにすると Credential Guard の入力系判定と二重管理になる。
if printf '%s' "$STDIN_JSON" | grep -q 'claude-in-chrome__computer'; then
  if printf '%s' "$STDIN_JSON" | grep -qE '"action"[[:space:]]*:[[:space:]]*"(screenshot|scroll|zoom|cursor_position|wait|hover|mouse_move)"' && \
     ! printf '%s' "$STDIN_JSON" | grep -qE '"action"[[:space:]]*:[[:space:]]*"(left_click|right_click|middle_click|double_click|triple_click|click|type|key|hold_key|left_click_drag|drag|left_mouse_down|left_mouse_up)"'; then
    exit 0
  fi
fi

# Money Watch 停止フラグ: 金銭・契約系画面の検知後は、ユーザー承認による解除まで変更操作を全て deny。
# JS実行系より前に置く（コード実行は mutation 可能なため、金銭停止中は無条件で止める＝フェイルクローズ）。
if [ -f "$WF_DIR/money_alert" ]; then
  deny_decay money \
    "【Money Watch】金銭・契約・不可逆登録系の画面を検知したため変更操作を停止中です（検知: $(cat "$WF_DIR/money_alert" 2>/dev/null | head -c 80)）。復帰手順の正本 docs/steps/money-recovery.md を Read して従うこと。ユーザーの明示承認なしに停止を解除することは禁止です。" \
    "【Money Watch】停止中（money_alert）。復帰は docs/steps/money-recovery.md を Read。"
fi

# JS実行系（javascript_tool / browser_evaluate / browser_run_code）は読み取り計測にも使うため、
# 明らかに読み取り専用のコードだけ workflow-init ゲート（active/b4/e）を免除して素通しする。
# 注意: 任意 JS の mutation 判定を denylist で完全網羅はできない（eval/Function/難読化で回避可能）。
# よって denylist は best-effort に過ぎず、硬い防御は上の Money Watch と Credential Guard・URL Guard が担う。
# denylist に当たる or 判定不能なコードは素通しせず、下の workflow ゲートを必ず通す（フェイルクローズ寄り）。
if printf '%s' "$STDIN_JSON" | grep -qE '(javascript_tool|browser_evaluate|browser_run_code)'; then
  if ! printf '%s' "$STDIN_JSON" | grep -qE '\.click\(|\.submit\(|requestSubmit|dispatchEvent|\.value[[:space:]]*=|innerHTML[[:space:]]*=|insertAdjacentHTML|location(\.href)?[[:space:]]*=|location\.(assign|replace)|\.href[[:space:]]*=|window\.open|fetch\(|XMLHttpRequest|sendBeacon|navigator\.send|localStorage\.(set|remove|clear)|sessionStorage\.(set|remove|clear)|document\.cookie[[:space:]]*=|\.focus\(\).*type|execCommand|\beval\b|new[[:space:]]+Function|Function\(|setTimeout|setInterval|\bimport\b|Reflect\.(apply|set)|\[[[:space:]]*["'"'"']|\[[a-zA-Z_$][^]]*\][[:space:]]*\('; then
    exit 0
  fi
fi

# network_request の読み取り専用 GET/HEAD は workflow-init ゲートを免除（money_alert 停止中は止めたまま — 任意 URL の HTTP 取得は復帰手順に不要なので安全側）（上の NR_READONLY 判定。Money/Credential/URL 判定は済み）
[ "$NR_READONLY" = "1" ] && exit 0

# browser_batch: 同梱 invocation が全て読み取り系なら素通しする（閲覧タスクを止めない）。
# 変更系ツール名（computer/form_input/JS実行/navigate）・変更系 action が1つでも含まれる、
# または判定不能な場合はゲートを通す（フェイルクローズ）。Money/Credential 判定は上で実施済み。
if printf '%s' "$STDIN_JSON" | grep -q 'browser_batch'; then
  if ! printf '%s' "$STDIN_JSON" | grep -qE '(__computer|form_input|javascript_tool|shortcuts_execute|navigate|"action"[[:space:]]*:[[:space:]]*"(left_click|right_click|middle_click|double_click|triple_click|click|type|key|hold_key|left_click_drag|drag)")'; then
    exit 0
  fi
fi

if [ ! -f "$WF_DIR/active" ]; then
  deny_decay init \
    "【SEO Worker Gate】ワークフロー未初期化。/SEO記事 の手順0（procedures/seo-start.md）（procedures/seo-start.md）でタスクを開始し、B-4（フェーズ判定）を完了してください（browser_batch は変更系を1つでも含むと一括でゲート対象になります）。" \
    "【SEO Worker Gate】未初期化（active なし）。手順: procedures/seo-start.md"
fi

# b4_done は「フラグの存在」だけでなく「phase にフェーズ判定が記録されていること」も要求する
# （2026-07-28: phase が空でも b4_done だけで通っていた＝判定を飛ばした迂回が成立していた）
PHASE_VAL=""
[ -f "$WF_DIR/phase" ] && PHASE_VAL="$(tr -d '[:space:]' < "$WF_DIR/phase" 2>/dev/null)"
if [ ! -f "$WF_DIR/b4_done" ] || [ -z "$PHASE_VAL" ]; then
  deny_decay b4 \
    "【SEO Worker Gate】B-4（フェーズ判定）が未完了です（b4_done またはフェーズ記録なし）。/SEO記事 の手順0（procedures/seo-start.md）（procedures/seo-start.md）の手順に戻り、B-4 で判定したフェーズ（1〜4、または first / return / remap / optimize）を memory/.workflow/phase に記録してから変更操作を行ってください。判定せずフラグだけ立てて迂回することは禁止です。" \
    "【SEO Worker Gate】B-4未完了（b4_done または phase が空）。手順: procedures/seo-start.md"
fi

# 一括送出タスク（Step F で bulk_send 宣言）は pre-publish-verifier 監査完了（psv_done）まで変更操作を止める
if [ -f "$WF_DIR/bulk_send" ] && [ ! -f "$WF_DIR/psv_done" ]; then
  deny_decay psv \
    "【SEO Worker Gate】公開・投稿を含むタスクは pre-publish-verifier の敵対的監査（VERDICT）とユーザー承認が先です。監査完了後に psv_done を立ててから実行してください（手順の正本: docs/steps/review.md）。フラグだけ立てる迂回は禁止です。" \
    "【SEO Worker Gate】psv_done 未了（pre-publish-verifier 監査が先）。手順: docs/steps/review.md"
fi

if [ ! -f "$WF_DIR/e_done" ]; then
  deny_decay e \
    "【SEO Worker Gate】Step E（変更前記録）が未完了です。read_page（Claude in Chrome）または browser_snapshot（Playwright）で変更前の状態を記録・保存してから進んでください（手順の正本: procedures/seo-start.md）。記録せずフラグだけ立てる迂回は禁止です。" \
    "【SEO Worker Gate】Step E（変更前記録）未完了。手順: procedures/seo-start.md"
fi

# ここまで来たら停止要因なし = 減衰カウンタを捨てる（次に止まったときは再びフル文言で伝える）
deny_reset

# --- Money Watch 操作直前判定（2026-09-10） ---
# 画面全体ではなく「これから操作する対象」を照合する。
#   【強】は操作先の識別子（element / ref / selector / name / label / aria-label / description / text の
#        うち識別子キー）だけを見る。入力本文（text / value / fields）は見ない — 「退会手続きについて解説します」
#        のような原稿入力で money_alert が立って session がロックする誤爆を防ぐ（2026-09-10 レビュー指摘）。
#   【弱】は tool_input 全体を見て警告のみ（additionalContext）。
#   money-suppress.txt はページ用の誤検知チューニングなので、弱警告にだけ効かせ強判定には効かせない。
# 複数行 JSON でも切り出せるよう先に改行を潰す。tool_input が取れない場合は識別子が無い＝強判定は
# できないので弱警告だけを本文全体で行う（座標クリックも同様。read_page / get_page_text / JS の戻り値側の検知が担う —
#   screenshot だけで進む経路には画面側の検知が無いので、変更前記録にテキスト読取を必ず含める規範（delve-start 手順3）が前提）。
ONELINE="$(printf '%s' "$STDIN_TEXT" | tr '\r\n' '  ')"
TARGET="$(printf '%s' "$ONELINE" | sed -n 's/.*"tool_input"[[:space:]]*:[[:space:]]*//p')"
[ "${#TARGET}" -ge 8 ] || TARGET="$ONELINE"
TARGET_ID="$(printf '%s' "$TARGET" | grep -oE '"(element|ref|selector|name|label|aria-label|description|button|link)"[[:space:]]*:[[:space:]]*"([^"\]|\.)*"' 2>/dev/null | tr '\r\n' '  ')"
if [ -n "$TARGET_ID" ]; then
  strong_t="$(money_strong "$TARGET_ID")"
  if [ -n "$strong_t" ]; then
    mkdir -p "$WF_DIR" 2>/dev/null
    printf '%s' "$strong_t" > "$WF_DIR/money_alert"
    deny_decay money \
      "【Money Watch・操作直前】操作対象に金銭・契約・不可逆登録の確定表現があります（パターン: $strong_t）。memory/.workflow/money_alert を設置し停止しました。復帰手順の正本 docs/steps/money-recovery.md を Read して従うこと（ユーザーの明示承認なしの解除は禁止）。" \
      "【Money Watch・操作直前】停止（money_alert 設置）。復帰は docs/steps/money-recovery.md を Read。"
  fi
fi
if ! money_suppressed "$TARGET"; then
  weak_t="$(money_weak "$TARGET")"
  if [ -n "$weak_t" ]; then
    warn_pretool "【Money Watch・操作直前】これから操作する要素に金銭系の文言があります（パターン: $weak_t。この警告は操作ごとに出ます）。停止はしていません — この操作がプラン変更・課金・支払い設定そのものなら実行せず docs/steps/money-recovery.md に従い、ユーザーの承認を得てから進むこと。"
  fi
fi
exit 0

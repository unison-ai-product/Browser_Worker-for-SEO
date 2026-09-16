#!/bin/bash
# Publish Guard — PreToolUse:Bash
# (a) オート公開ガード: WordPress REST への投稿で status=publish / future / private を機械的に止める。
#     このプラグインが自律で作ってよいのは「下書き（draft / pending）」だけ。公開は人間が WP 管理画面で行う。
# (b) 無チェックゲートガード: WP への投稿（下書きでも）は、ルール＆レギュレーションゲート通過の証跡
#     memory/.workflow/gate_pass が無ければ止める（フィックスループを飛ばした投稿を防ぐ）。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

CMD="$(printf '%s' "$STDIN_TEXT" | sed -n 's/.*"command":"\(.*\)".*/\1/p' | head -c 20000)"
[ -n "$CMD" ] || CMD="$STDIN_TEXT"

# (a0) WP-CLI / PHP / SQL 経由の公開は書き方を問わず拒否（wp post update --post_status / wp eval wp_publish_post / wp db query UPDATE ... post_status）
# 読むだけの `wp post list/get --post_status=publish` は対象外（update / eval / db を伴わない場合）
WP_READ_ONLY=0
if printf '%s' "$CMD" | grep -qiE 'wp[ ]+post[ ]+(list|get)' && ! printf '%s' "$CMD" | grep -qiE 'wp[ ]+(eval|eval-file|db)|post[ ]+(update|create|publish)|wp_publish_post|wp_update_post'; then WP_READ_ONLY=1; fi
if [ "$WP_READ_ONLY" = "0" ] && printf '%s' "$CMD" | grep -qiE 'wp_publish_post|wp_update_post|post_status|wp[ ]+(eval|eval-file|db[ ]+query|post[ ]+(publish|update))'; then
  if printf '%s' "$CMD" | grep -qiE 'publish|future|private'; then
    deny "【Publish Guard】WP-CLI / PHP / SQL を経由した公開ステータスの変更（wp eval / wp db query / wp post update --post_status=publish 等）は AI には許可されていません。公開はユーザー本人が WP 管理画面で行ってください。"
  fi
fi

# (a1) REST の直叩き（curl / python requests / wp-json・rest_route）は書き方を問わず拒否。正規の経路は wp-draft.py だけ
#      （JSON 本文の status はエスケープ・ファイル参照・別言語で書けるので文字判定では網羅できない）
if printf '%s' "$CMD" | grep -qiE 'wp-json/wp/v2/(posts|pages)|rest_route=/?wp/v2/(posts|pages)' && ! printf '%s' "$CMD" | grep -qiE 'wp-draft\.py'; then
  deny "【Publish Guard】WordPress REST（wp-json/wp/v2/posts）の直接呼び出しは AI には許可されていません。投稿は scripts/wp-draft.py（下書きのみ）を使ってください。"
fi

# WP 投稿を伴うコマンドか（wp-draft.py / wp-json/wp/v2/posts への POST・PUT / wp post create）
if printf '%s' "$CMD" | grep -qiE 'wp-draft\.py|wp-json/wp/v2/(posts|pages)|wp[ ]+post[ ]+(create|update)'; then
  # (a) 公開ステータスの機械拒否
  if printf '%s' "$CMD" | grep -qiE -- '--status[= ]+(publish|future|private)|"status" *: *"(publish|future|private)"|status=(publish|future|private)|--publish|post_status=(publish|future|private)'; then
    deny "【Publish Guard】WordPress への公開（status=publish/future/private）は AI には許可されていません。このプラグインが投稿できるのは下書き（draft）のみです。公開はユーザー本人が WP 管理画面で行ってください。"
  fi
  # --check（接続確認）は投稿ではないので以下の証跡検査を免除
  if printf '%s' "$CMD" | grep -qE -- '--check'; then exit 0; fi
  # (b) ゲート通過証跡
  if [ ! -f "$WF_DIR/gate_pass" ]; then
    gate_emit gate "Gate Guard" \
      "【Gate Guard】ルール＆レギュレーションゲート（keyword-gate + fact-checker + fix-integrator の PASS）を通過した証跡 memory/.workflow/gate_pass がありません。procedures/seo-write.md 手順6 のゲートを通し、PASS を echo で記録してから WP に投稿してください。証跡だけ作って迂回することは禁止です。" \
      "【Gate Guard】gate_pass なし。手順: procedures/seo-write.md 手順6"
  fi
  # (c) 送信前監査の証跡（pre-publish-verifier の VERDICT GO → psv_done）
  if [ ! -f "$WF_DIR/psv_done" ]; then
    gate_emit psv "PSV Guard" \
      "【PSV Guard】pre-publish-verifier の送信前監査（VERDICT: GO）の証跡 memory/.workflow/psv_done がありません。procedures/seo-write.md 手順7 の監査を通してから WP に投稿してください。フラグだけ立てる迂回は禁止です。" \
      "【PSV Guard】psv_done なし。手順: procedures/seo-write.md 手順7"
  fi
fi
exit 0

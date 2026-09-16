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

# WP 投稿を伴うコマンドか（wp-draft.py / wp-json/wp/v2/posts への POST・PUT / wp post create）
if printf '%s' "$CMD" | grep -qiE 'wp-draft\.py|wp-json/wp/v2/(posts|pages)|wp[ ]+post[ ]+(create|update)'; then
  # (a) 公開ステータスの機械拒否
  if printf '%s' "$CMD" | grep -qiE -- '--status[= ]+(publish|future|private)|"status" *: *"(publish|future|private)"|status=(publish|future|private)|--publish|post_status=(publish|future)'; then
    deny "【Publish Guard】WordPress への公開（status=publish/future/private）は AI には許可されていません。このプラグインが投稿できるのは下書き（draft）のみです。公開はユーザー本人が WP 管理画面で行ってください。"
  fi
  # (b) ゲート通過証跡
  if [ ! -f "$WF_DIR/gate_pass" ]; then
    gate_emit gate "Gate Guard" \
      "【Gate Guard】ルール＆レギュレーションゲート（keyword-gate + fact-checker + fix-integrator の PASS）を通過した証跡 memory/.workflow/gate_pass がありません。procedures/seo-write.md 手順6 のゲートを通し、PASS を echo で記録してから WP に投稿してください。証跡だけ作って迂回することは禁止です。" \
      "【Gate Guard】gate_pass なし。手順: procedures/seo-write.md 手順6"
  fi
fi
exit 0

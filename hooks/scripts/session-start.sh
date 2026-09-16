#!/bin/bash
# SEO Worker Session Start — 前回未完了タスクの通知 + 環境情報
#
# 【原則】通知は「該当する場合のみ1行」。この出力は全セッションの先頭に必ず載るため、
# 常時出る説明文・手順の写しを増やさない（手順は正本ファイルへのポインタ1行で足りる）。
# 追加するなら必ず条件付き（if で該当時だけ PREFIX に足す）にすること。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# deny 減衰カウンタはセッションをまたいで持ち越さない（新セッションでは1回はフル文言で伝える）
deny_reset
money_weak_seen_reset

# 注意: warn_session は exit するため、呼べるのは1回だけ。メッセージは PREFIX に集約する
PREFIX=""
if [ -f "$WF_DIR/active" ] && [ ! -f "$WF_DIR/k_done" ]; then
  task="$(cat "$WF_DIR/active" 2>/dev/null | tr -d '\n"\\')"
  PREFIX="【SEO Worker】前回のタスク「$task」が未完了です（k_done なし）。memory/session-log.md を確認して引き継ぐこと。 "
fi

# 残留フラグ通知（2026-07-27 過剰ゲート監査）: 前セッションが途中で切れると停止系フラグが残り、
# 新しいセッションが「なぜか全部ブロックされる」状態で始まる。原因をここで先に開示する。
# フラグを消すのは各復帰手順の仕事で、この hook は消さない（通知のみ）。
STALE=""
[ -f "$WF_DIR/money_alert" ] && STALE="${STALE}money_alert（変更操作が全て停止中／復帰は docs/steps/money-recovery.md）, "
[ -f "$WF_DIR/verify_allowlist" ] && STALE="${STALE}verify_allowlist（検証モード＝許可サイト以外へ navigate 不可。検証タスク中でなければ残留です）, "
[ -f "$WF_DIR/bulk_send" ] && [ ! -f "$WF_DIR/ov_done" ] && STALE="${STALE}bulk_send（公開後のブラウザ確認（ov_done）なしでタスク完了が不可）, "
if [ -n "$STALE" ]; then
  PREFIX="${PREFIX}【残留フラグ】memory/.workflow/ に前セッションの停止系フラグが残っています: ${STALE%, }。操作がブロックされたら原因はこれです。**勝手に rm して解除しないこと** — 各フラグの正規の復帰手順に従うか、残留だと判断できる場合はユーザーに1行で伝えて指示を仰ぐ。全体像は /SEO検証 で一覧できます。 "
fi

# session-log 肥大検知（該当時のみ1行）: 引き継ぎで毎回全文を読む前提のファイルなので、
# 膨らむと全セッションの読み取りコストになる。閾値超過だけ圧縮を促す
SESSION_LOG="$PROJECT_DIR/memory/session-log.md"
if [ -f "$SESSION_LOG" ]; then
  LOG_LINES="$(wc -l < "$SESSION_LOG" 2>/dev/null | tr -dc '0-9')"
  if [ -n "$LOG_LINES" ] && [ "$LOG_LINES" -gt 400 ]; then
    PREFIX="${PREFIX}【session-log】${LOG_LINES}行に肥大しています。手動で古い節を knowledge/logs/ へ退避して圧縮すること。 "
  fi
fi

# 永続化チェック: ワークスペースに蓄積の痕跡（knowledge/）が無い場合、
# クラウドセッションの一時領域で動いている可能性が高い（セッション終了で蓄積消失）。
# 注: .git の存在は永続化の根拠にしない（クラウドコンテナ内の clone でも .git は存在するため）
if [ ! -d "$PROJECT_DIR/knowledge" ]; then
  PREFIX="${PREFIX}【永続化警告】このワークスペースに蓄積（knowledge/）がありません。永続フォルダ未接続の可能性があり、その場合 memory/ と knowledge/ の蓄積はセッション終了で消えます。ユーザーに永続フォルダの接続を1行で推奨し、未接続のまま進める場合は蓄積系機能（skillify/feedback/watchスナップショット）の成果を必ず成果物としてユーザーに渡すこと。 "
fi

# 初期セットアップ: 未回答のときだけ1行案内（回答済みなら何も注入しない = コンテキスト消費ゼロ）
SETUP_FILE="$PROJECT_DIR/knowledge/config/setup.yaml"
if [ -d "$PROJECT_DIR/knowledge" ] && [ ! -f "$SETUP_FILE" ]; then
  PREFIX="${PREFIX}【セットアップ】初期ヒアリング未回答。最初の依頼の前に /SEO設定（procedures/seo-setup.md）を1行で案内すること（強制はしない）。 "
elif [ -f "$SETUP_FILE" ] && grep -q "completed: pending" "$SETUP_FILE" 2>/dev/null; then
  PREFIX="${PREFIX}【セットアップ】未回答の項目が残っている（setup.yaml: pending）。区切りの良いタイミングで /SEO設定 の続きを1行で案内。 "
fi

# タスクPack設定（knowledge/config/packs.conf）: off のパックを通知に含める
PACKS_CONF="$PROJECT_DIR/knowledge/config/packs.conf"
if [ -f "$PACKS_CONF" ]; then
  OFF_PACKS="$(grep -E '^[a-z-]+=off' "$PACKS_CONF" 2>/dev/null | cut -d= -f1 | grep -v '^core$' | tr '\n' ',' | sed 's/,$//')"
  if [ -n "$OFF_PACKS" ]; then
    PREFIX="${PREFIX}【タスクPack】無効: ${OFF_PACKS} — 該当パックの機能は使わない・提案しない・自動発火させない（定義は procedures/seo-setup.md（/SEO設定 の機能ON/OFF）参照。ユーザーが明示要求したときのみON化を1行案内）。 "
  fi
fi

# 運用ルール本文は session-rules.txt が正本（bash文字列への直書き禁止 — 編集性とエスケープ事故防止）
RULES_FILE="$SCRIPT_DIR/session-rules.txt"
# warn_session は exit するため、正常系とフォールバックは if/else で明示的に分岐させる
# （以前は if の後ろにフォールバックを置いていたが、正常系が exit するため「if を抜けた後」に
#   到達する経路が読み取りづらかった。else にして到達条件＝rules 欠損のみを明示する）
if [ -f "$RULES_FILE" ]; then
  RULES="$(tr '\n' ' ' < "$RULES_FILE")"  # エスケープは warn_session（json_escape）に一元化
  warn_session "${PREFIX}${RULES}"
else
  warn_session "${PREFIX}【SEO Worker】session-rules.txt が見つかりません（プラグイン破損の可能性）。docs/conventions.md と各コマンドの手順に従い、変更操作は必ず /SEO記事 の手順0（procedures/seo-start.md） から行うこと。"
fi

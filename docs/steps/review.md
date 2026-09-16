# Step H — レビュー・承認・監査の手順（正本）

> `docs/steps-reference.md` の Step H 行から分離（2026-09-10）。**生成物の承認・不可逆送出・ビジュアル成果物の引き渡しがあるときだけ読む**（内容の移動のみ）。
> 読み取りだけのタスク、承認対象の無いタスクでは読まない。

## 1. 承認の取り方

- 生成物・破壊的操作はユーザー承認を取る（無人運用時は docs/unattended-ops.md の承認キューに従う）
- **N件はまとめて1回で一覧提示し、承認は個別に取る**（[speed.md](speed.md) §3。減らすのは提示の往復だけで、承認の粒度は変えない）

## 2. 不可逆送出の敵対的監査（pre-send-verifier）

- 一括送信・投稿・入稿など不可逆送出は、**承認提示の前に pre-send-verifier サブエージェントの敵対的監査（VERDICT）を材料として添える**
- 監査とユーザー承認が揃ったら `touch memory/.workflow/psv_done`（bulk_send 宣言済みタスクは psv_done まで hook が変更操作をブロック）
- **監査は「送る対象が確定した1回」だけ**（計画段階と選定後の2回に分けない）
- 渡すのは判断の説明ではなく**確定した対象の表**（識別番号・属性・使用テンプレ・添付先）
- 周回の上限は agents/pre-send-verifier.md「収束条件」に従う。実行体の組み立ては [bulk-send.md](bulk-send.md)

## 3. ビジュアル成果物の審査（design-critic）

- **design-artisan のビジュアル生成物のうちユーザーに渡す最終成果物は必ず design-critic の審査を経てから承認に出す**（critic 未経由の直接引き渡しは禁止 — Critic Gate hook が送付出口で強制）
- **中間物は対象外**（作業確認用スクショ・検証中のダミー・自分で見るだけの試作は critic を呼ばない。Critic Gate と同じ線引き）
- フラグ運用:
  1. artisan へ委譲した直後: `echo "<レビュー対象のファイル名またはパターン>" > memory/.workflow/critic_pending && rm -f memory/.workflow/critic_pass`（**対象を書くこと** — 空にすると全ビジュアル成果物が対象になり、デバッグ用スクショまで送付できなくなる）
  2. critic が PASS を返したら `rm memory/.workflow/critic_pending` し、PASS の1行要約を `memory/.workflow/critic_pass` に書き込む
  3. REVISE が返ったら、メインループが FIX 内容を design-artisan に再投入し PASS まで反復してから承認に出す（周回上限は agents/design-critic.md「収束条件」に従う）
- 見た目ものの成果物は、承認の選択肢として「Claude Design ハンドオフ（docs/parts/design-handoff.md）」も提示してよい。ハンドオフしたら成果物の最終正本は回収後のファイルとする

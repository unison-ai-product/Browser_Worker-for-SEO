# 読み取りと提示の速度規範（正本）

> 複数ページ・複数候補を扱うときに読む。**速くするのは読み取りと提示であって、承認と送出ではない**（承認の粒度・ゲート・監査は一切緩めない）。
> 凍結の条件は [freeze.md](freeze.md)。ここの規範は**フェーズ①②でも適用される** — 凍結前でも1コール集約はできる。

## 1. 読み取りは1コールに集約する

- **複数ページ/複数候補を扱うときは、読み取りを `javascript_tool` の1コールに集約する。1件ずつの read_page 往復をデフォルトにしない**
- 実行可能なら `browser_batch` で束ねる（navigate + 抽出のような固定列を1呼び出しに）
- 同じページで複数観点（速度・品質・リンク健全性・ライセンス等）を測るなら、観点ごとにコールを分けず**1コールで全観点を1つのオブジェクトで返す**
- 返った JSON は表にして提示 = そのまま dry-run 出力・Step H の監査入力になる

一覧 → JSON 一括抽出の型（N回の read_page が1回になる。判定・整形は返った JSON 側で行う）:

```js
[...document.querySelectorAll('.list .item')].map(e => ({
  id: e.dataset.id, name: e.querySelector('.name')?.textContent.trim(),
  attrs: [...e.querySelectorAll('.tag')].map(t => t.textContent.trim()),
  url: e.querySelector('a')?.href,
}))
```

## 2. `browser_batch` の制約（守らないと逆に遅い）

入れ子不可 / ホワイトリスト外の子で呼び出し全体が拒否 / **最初のエラーで停止（後続は未実行）**。
**変更系の子はゲート対象のまま**（batch に束ねても b4_done / e_done / psv_done は必要）。実測仕様は [../rationale.md](../rationale.md)。

## 3. 承認提示のバッチ化

**N件の下書き・候補を1回で一覧提示 → 承認は個別に取る。** 減らすのは提示の往復だけで、承認の粒度は変えない。
対話中も unattended-ops.md の承認キューの型（承認ID付きで `knowledge/approvals/pending.md` に記録 → 一括提示 → 個別に承認）を使う。

## 4. UI操作を諦めて `javascript_tool` に切り替えるシグナル

以下を検出したら UI 操作（`computer` のクリック／`form_input`）を続けず、即 `javascript_tool`（必要なら `browser_batch` で束ねる）へ切り替える:

| シグナル | 切り替え先 |
|---|---|
| `read_page` / snapshot が巨大（50KB超 or 出力上限） | `javascript_tool` で必要な値だけ抽出（件数 `querySelectorAll(...).length`・状態は textContent）。ボタン押下も `scrollIntoView()` → `click()` |
| カスタムUIコンポーネント（Vue/React 等）で入力・選択が効かない | `javascript_tool` で native setter + `dispatchEvent('input'/'change')` |
| 一覧取得にページ送りの反復が必要 | `javascript_tool` の一括抽出（1コールで全項目 JSON 化。ページ送りを回さない） |
| 非同期完了待ち（メール通知型・バックグラウンド処理） | 画面待機をやめ、完了状態を返す取得系（下記 §5 の状態確認）に切り替える |

**UI試行は1回で見切る**（シグナル検出後に同じ UI 操作を2回以上試さない — 試行の往復がそのまま遅延になる）。**変更系はどちらの経路でもゲート対象のまま**（`javascript_tool` / `browser_batch` も matcher 内）。

## 5. 待機は短く刻む

- 長い処理待ちを**1回の長 wait で通さない**。「短い wait（0.3〜1秒）+ 状態確認（期待テキスト／要素の出現チェック）」の反復にする（準備でき次第すぐ次へ進むので速く、かつ何を待っていたかがログに残る）
- **上限を決める**（目安 15〜18 秒。それ以上待つ設計にしない）。超えたら**停止してユーザーに報告**する — 自動リカバリも延長もしない
- 固定 sleep が要るのはレート制御だけ（連続送出の 1.2 秒以上 + ランダム待機 → [bulk-send.md](bulk-send.md) §5）

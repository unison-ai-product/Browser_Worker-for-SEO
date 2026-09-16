# 認証フィールドの取り扱い（全ステップ共通・自己規律 — 正本）

> `docs/steps-reference.md` から分離（2026-09-10）。**全フェーズ必読**（delve-start 手順0.5 から Read。既知の限界 E1（docs/escalations.md）の主防御はこの自己規律で、hook は最後の網）。

Credential Guard（hook）はペイロード内のキーワードで検知するため、**参照ID（ref）だけを指定した入力はすり抜けうる**（2026-07-24 実測: ref 経由で password 欄への入力が素通りした）。hook は最後の網であって主防御ではない — 以下を自己規律として守る:

- ログイン・認証画面では **autofill の起動（クリックのみ）以外の入力操作をしない**。ref 指定の form_input/type も禁止（ref の先が password 欄かどうかは入力前に要素の type/autocomplete 属性を read_page で確認しない限り分からない）
- 入力先が不明な ref に対する入力は、直前の read_page で要素種別を確認してから行う（type=password / autocomplete=current-password・one-time-code の要素なら入力せず人間に委譲）

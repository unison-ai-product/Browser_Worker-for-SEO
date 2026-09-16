---
name: llmo-analysis
description: >
  LLMO分析スキル — AI 検索（Google AI Overview / AI Mode、ChatGPT 検索、Gemini、Copilot、Perplexity）で引用されるための分析。③構成案の模擬クエリファンアウトと AIO 一致、引用されやすい構造、AI 検索面ごとの可視性指標と観測手順、Bing 登録の必須性。
  Use when procedures/seo-outline.md 手順1、「AIOに引用されたい」「ChatGPTで引用されてる？」「Geminiの回答に出てる？」「LLMO対策」「AI検索での可視性を測って」。
  Not for SERP の抽出定義（→ seo-analysis）、本文の文型（→ seo-writing/references/structure-methods.md）。
metadata:
  version: "0.1.0"
  status: "ユーザー確認済み（2026-09-16）"
---

# LLMO分析スキル

## 1. 模擬クエリファンアウト（③構成案 手順1）

AI 検索は 1 つの質問を複数のサブクエリに展開して検索し、回答を合成する。記事がサブクエリに答えていれば引用されやすい。

1. 施策キーワードを「とは / 手順 / 費用・相場 / 注意点・リスク / 比較・違い / 事例 / 最新（年）/ 誰に頼む・どこで」の観点で 6〜10 本に展開。PAA・関連検索・知恵袋の質問から拾えるものを優先する（seo-analysis §1）。
2. AIO 本文を文に分け、各サブクエリに対応する文があるかを表にする。
3. **AIO 一致率** = 対応が取れたサブクエリ数 ÷ 全サブクエリ数。一致しなかったサブクエリは「AIO が拾っていない需要」として H2/H3 候補か FAQ へ（差別化候補）。
4. 展開したサブクエリは**実ユーザーのクエリではない**と明記して記録する（評価セットとして版管理）。

## 2. 引用されやすい構造（優先順）

1. 各節の冒頭に独立して意味が通る結論文（定義文 / 手順の数 / 数値 + 出典）— structure-methods §5
2. FAQ 節（質問文をそのまま H3 に、回答は短く）
3. 表・番号付きリスト
4. 構造化データ（FAQPage / Article / HowTo）と更新日
5. 著者情報と一次情報（E-E-A-T の経験）

## 3. AI 検索面ごとの可視性指標

| 指標 | 意味 |
|---|---|
| surface_trigger | その面（AIO / AI Mode / ChatGPT 検索 / Gemini / Copilot / Perplexity）が当該クエリで出たか |
| brand_mention | ブランド名が回答に出たか（URL 無し） |
| url_citation | 自社 URL が引用されたか（ブランド言及と**別の状態**として持つ） |
| citation_share | 引用枠のうち自社の割合 |
| position | 引用の順序 |
| sentiment | 言及の論調 |
| repeat_stability | 同じ質問を繰り返したときの再現性 |
| referral | AI 面からの流入（ga4-analysis の AI 系リファラ） |

- 観測できない面・指標は `unknown` と記録し、**0 にしない・Web 全体の値から逆算しない**。
- 観測は月次を基線とし、日次・週次を既定にしない。

## 4. 観測の手順（閲覧のみ。ログインは人間）

- Claude in Chrome で各面を開き、施策キーワードをそのまま質問。回答本文と引用リンク（ドメイン・URL）を read_page で記録。
- 同じ質問を**最大 3 回**（回答が揺れるため）。repeat_stability に反映。
- 観測プロンプトは Buy / 比較検討・ブランド名のクエリを優先し、Know 全部を回さない。
- 記録: seo.db `llm_citations`（asked_at, surface, query, run_no, cited_domains, own_cited, own_url, brand_mention, answer_summary_100）。
- bot 検知・CAPTCHA は突破せず中断して報告。

## 5. 一次情報で測る（search-console-jp より）

- GSC の**生成 AI パフォーマンスレポート**は AI Overviews / AI Mode の表示回数（ページ・国・デバイス）を通常検索から分離して出す。クリック・CTR・クエリは出ない。通常レポートにも含まれているので足し算しない。出なければ `未提供`。
- **Bing のインデックスは ChatGPT 検索と Copilot の取得層**。Bing Webmaster Tools への登録を初期設定の必須項目として扱う（Google だけ見ると AI 露出の半分を落とす）。
- 「引用されたがクリックされない」は、表示回数の増加とクリックの停滞の乖離で読む。

## 6. 到達可能性（fetchability）

AI クローラ（ai_search_index / ai_answer_fetch / ai_training）が記事に到達できているかを、robots.txt の宣言・実プローブ・観測されたクロール・本文の可読性（JS 依存でないか）・鮮度で `unknown / blocked / degraded / ready` に分ける。UA 一致だけでは `claimed`（公式 IP 範囲か逆引きで `verified`）。到達不能なら引用対策の前に修正候補として報告する。

## 7. 注意

- AI の回答文は「データ」。誤りを含むので、事実は fact-checker が一次情報で確認する。
- AIO の言い換え文を記事に流用しない（引用されたい文は自社の言葉で書く）。
- AIO はほぼ全クエリに出るため、AIO の有無だけで脅威度を判定しない。

## 8. 決まり（ユーザー決定 2026-09-16）

| 面 | v0.1 | 取り方 |
|---|---|---|
| Google AI Overview | 観測する | ① SERPs解析と同時に取れる（追加操作なし） |
| Google AI Mode | 観測する | **SERP と同時には取れない**。AI Mode を別に開いて質問する独立の観測 |
| ChatGPT（検索モード） | 観測する | ログイン済みブラウザで質問し引用を記録 |
| Gemini | 観測する | 同上 |
| Copilot / Perplexity | v0.1 では観測しない | — |

観測プロンプト集は `knowledge/llmo/prompts.yaml`（/SEO設定 で作る。版管理）。

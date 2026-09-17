# サブエージェント配役表（正本）

Subagent Guard はこの表の名前だけを通す。級は「外したら後から直すのが高いか」で決まっている。**下の級に上の級の仕事をさせない**（Haiku に執筆させない、Sonnet に統合判断をさせない）。同時起動は最大 4 体。

| 名前 | 級 / モデル | effort | 役割 | 呼ぶステージ |
|---|---|---|---|---|
| serp-collector | 実行 / Sonnet | medium | Google SERP を読み取り、AIO・順位・PAA・関連語を定義どおりに抽出 | ① |
| article-analyzer | 実行 / Sonnet | medium | 上位記事 1 本の見出し・内部リンク・主張分類・AIO 引用箇所・構造化データを抽出 | ②（記事ごとに 1 体） |
| unit-drafter | 実行 / Sonnet | medium | ユニット 1 つの本文をライティングスキルと媒体ルールで執筆 | ④（U1・U2・U3 の 3 体同時） |
| diagram-maker | 実行 / Sonnet | medium | H2 テーマの図解（SVG / Mermaid + alt + キャプション）を生成 | ④（並列 ≤4） |
| fact-checker | 検査 / Haiku | — | ユニット単位で数値・固有名詞・法規断定・出典を検査。修正はしない | ④ |
| keyword-gate | 検査 / Haiku | — | 必須キーワード網羅・媒体ルール項目を PASS/FAIL で検算。修正はしない | ③ ④ |
| pre-publish-verifier | 検査 / Haiku | — | WP 下書き投稿直前の敵対的最終監査（GO / NO-GO / UNVERIFIABLE） | ④ |
| fix-integrator | 統合判断 / Opus | medium | 3 ユニット + 図解 + facts を媒体ルールに合わせて 1 本の記事に統合 | ④ |
| adversarial-reviewer | 統合判断 / Opus | medium | 構成案の敵対検証・失敗時のエスカレーション相談 | ③・エスカレーション |

追加が必要なときはユーザーが `knowledge/config/agent-allowlist.txt` に名前を書く（AI が代行しない）。

---
description: 初期設定と記憶の入口。引数なしで初回設定を順に案内（保存先フォルダ→記憶DB→サイトプロファイル→スプレッドシート→WordPress→表記ルール。続きから再開）。WordPress接続（サイトURL・REST用アプリケーションパスワードは .env に人間が置く）、キーワードマップ／成果物スプレッドシートの指定、自社サイトドメイン、メディアルール（装飾・表記・レギュレーション）の抽出と登録、ユーザーオリジナルメモリ（主張・一次情報）、機能ON/OFF、SQLite記憶DBの初期化。Use when 「初期設定」「フォルダ設定」「保存先を決めたい」「WPを登録して」「スプシを紐づけて」「うちの表記ルールを覚えて」「この主張を記憶して」「〇〇機能をOFFに」。手順の正本は procedures/seo-setup.md
argument-hint: [項目（folder / db / profile / sheet / wp / rules / memory / packs / feedback / status）]
---

プラグインの `procedures/seo-setup.md`（見つからなければ Glob `**/procedures/seo-setup.md`）を Read し、その手順に従って実行してください。引数: $ARGUMENTS

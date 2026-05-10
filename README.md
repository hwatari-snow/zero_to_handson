# Zero to Snowflake 入門ガイド

## 概要

このガイドでは、Snowflakeのコア機能を段階的に学びます。仮想ウェアハウスによるスケーラブルな計算処理、UNDROPによるシームレスなデータ復旧、リソースモニターによるコスト管理といった基本機能から始まります。次に、外部ステージや半構造化VARIANTデータの取り込み、ダイナミックテーブルを使った宣言的なデータ変換によるパイプライン構築を学びます。

さらに、Snowflake CortexのAI関数によるデータベース内AI活用や、CopilotによるSQL支援も紹介します。Snowflake Horizonを通じたガバナンス（ロールベースアクセス制御、カラムレベルマスキング、行レベルポリシー）の実装方法、Trust Centerによるセキュリティ監視も扱います。最後に、Snowflake Marketplaceからのデータ取得による分析の拡充と、Streamlitを使ったインタラクティブアプリケーションの構築を体験します。

## ステップバイステップガイド

前提条件、環境セットアップ、ステップバイステップの手順については、[クイックスタートガイド](https://quickstarts.snowflake.com/guide/zero_to_snowflake/index.html?index=..%2F..index#0)を参照してください。

## ファイル構成

```
.
├── README.md                    # このファイル
├── scripts/
│   ├── setup.sql                # 環境セットアップ（データベース、スキーマ、ウェアハウス、ロール作成）
│   ├── vignette-1.sql           # Snowflake入門（ウェアハウス、キャッシュ、クローン、Time Travel）
│   ├── vignette-2.sql           # シンプルなデータパイプライン（ステージ取り込み、ダイナミックテーブル）
│   ├── vignette-3-aisql.sql     # Cortex AI関数（感情分析、分類、抽出、要約）
│   ├── vignette-3-copilot.sql   # Snowflake Copilot（AI支援SQL開発）
│   ├── vignette-4.sql           # Horizonによるガバナンス（RBAC、マスキング、行アクセスポリシー）
│   └── vignette-5.sql           # アプリ＆コラボレーション（Marketplace、Streamlit）
├── semantic_models/
│   └── TASTY_BYTES_BUSINESS_ANALYTICS.yaml  # Cortex Analystセマンティックモデル
└── streamlit/
    └── streamlit_app.py         # Streamlitアプリサンプル
```

## 学習内容

- **Vignette 1: Snowflake入門** — 仮想ウェアハウス、キャッシュ、ゼロコピークローン、Time Travel
- **Vignette 2: シンプルなデータパイプライン** — 外部ステージからのデータ取り込み、ダイナミックテーブルによるELTパイプライン
- **Vignette 3: Snowflake Cortex AI** — Cortex Playground、AI関数、Cortex Search、Cortex Analyst
- **Vignette 4: Horizonによるガバナンス** — ロールベースアクセス制御、データ分類、マスキングポリシー、行アクセスポリシー
- **Vignette 5: アプリ＆コラボレーション** — Snowflake Marketplace、Streamlitアプリ開発

## 前提条件

- サポートされているSnowflake対応[ブラウザ](https://docs.snowflake.com/en/user-guide/setup#browser-requirements)
- Enterprise版またはBusiness Critical版のSnowflakeアカウント
- アカウントをお持ちでない場合は、[30日間無料トライアル](https://signup.snowflake.com/)にサインアップしてください（Enterprise版を選択してください）

## 使い方

1. `scripts/setup.sql` を実行して環境をセットアップ
2. 各Vignetteのスクリプトを順番に実行
3. 各スクリプト内のコメントに従って操作

## 元のリポジトリ

このリポジトリは [Snowflake-Labs/sfguide-getting-started-from-zero-to-snowflake](https://github.com/Snowflake-Labs/sfguide-getting-started-from-zero-to-snowflake) を日本語に翻訳したものです。

## ライセンス

Apache-2.0 License

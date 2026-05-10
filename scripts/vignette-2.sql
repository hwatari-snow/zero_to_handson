/***************************************************************************************************       
Asset:        Zero to Snowflake - Simple Data Pipeline
Version:      v2     
Copyright(c): 2025 Snowflake Inc. All rights reserved.
****************************************************************************************************

シンプルなデータパイプライン
1. 外部ステージからのデータ取り込み
2. 半構造化データとVARIANTデータ型
3. ダイナミックテーブル
4. ダイナミックテーブルを使ったシンプルなパイプライン
5. 有向非巡回グラフ（DAG）によるパイプラインの可視化

****************************************************************************************************/

ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "data_pipeline"}}';

/*
    TastyBytesのデータエンジニアとして、生のメニューデータを使ったデータパイプラインを作成します。
    まず適切なコンテキストを設定しましょう。
*/
USE DATABASE tb_101;
USE ROLE tb_data_engineer;
USE WAREHOUSE tb_de_wh;

/*  1. 外部ステージからのデータ取り込み
    ***************************************************************
    SQLリファレンス:
    https://docs.snowflake.com/en/sql-reference/sql/copy-into-table
    ***************************************************************

    現在、データはAmazon S3バケットにCSV形式で保存されています。この生のCSVデータを
    ステージに読み込み、作業用のステージングテーブルにCOPY INTOする必要があります。
    
    Snowflakeにおけるステージとは、データファイルの保存場所を指定する名前付きデータベースオブジェクトで、
    テーブルへのデータのロードやアンロードを可能にします。

    ステージを作成する際には以下を指定します：
                                - データの取得元となるS3バケット
                                - データを解析するためのファイルフォーマット（今回はCSV）
*/

-- メニューステージを作成
CREATE OR REPLACE STAGE raw_pos.menu_stage
COMMENT = 'Stage for menu data'
URL = 's3://sfquickstarts/frostbyte_tastybytes/raw_pos/menu/'
FILE_FORMAT = public.csv_ff;

CREATE OR REPLACE TABLE raw_pos.menu_staging
(
    menu_id NUMBER(19,0),
    menu_type_id NUMBER(38,0),
    menu_type VARCHAR(16777216),
    truck_brand_name VARCHAR(16777216),
    menu_item_id NUMBER(38,0),
    menu_item_name VARCHAR(16777216),
    item_category VARCHAR(16777216),
    item_subcategory VARCHAR(16777216),
    cost_of_goods_usd NUMBER(38,4),
    sale_price_usd NUMBER(38,4),
    menu_item_health_metrics_obj VARIANT
);

-- ステージとテーブルが準備できたので、ステージからmenu_stagingテーブルにデータをロードします。
COPY INTO raw_pos.menu_staging
FROM @raw_pos.menu_stage;

-- オプション: ロードが成功したことを確認
SELECT * FROM raw_pos.menu_staging;

/*  2. Snowflakeにおける半構造化データ
    *********************************************************************
    ユーザーガイド:
    https://docs.snowflake.com/en/sql-reference/data-types-semistructured
    *********************************************************************
    
    SnowflakeはVARIANTデータ型を使用して、JSONなどの半構造化データの処理に優れています。
    データを自動的に解析、最適化、インデックス化し、標準SQLと専用関数を使って簡単に抽出・分析できます。
    SnowflakeはJSON、Avro、ORC、Parquet、XMLなどの半構造化データ型をサポートしています。
    
    menu_item_health_metrics_objカラムのVARIANTオブジェクトには、2つの主要なキーバリューペアが含まれています：
        - menu_item_id: メニューアイテムの一意識別子を表す数値。
        - menu_item_health_metrics: 健康情報の詳細を含むオブジェクトの配列。
        
    menu_item_health_metrics配列内の各オブジェクトには以下が含まれます：
        - 文字列の配列であるingredients。
        - 'Y'および'N'の文字列値を持つ複数の食事制限フラグ。
*/
SELECT menu_item_health_metrics_obj FROM raw_pos.menu_staging;

/*
    このクエリでは、JSONライクな内部構造をナビゲートするための特殊な構文を使用します。
    コロン演算子（:）はキー名でデータにアクセスし、角括弧（[]）は配列から数値位置で要素を選択します。
    これらの演算子を連鎖させて、ネストされたオブジェクトから材料リストを抽出できます。
    
    VARIANTオブジェクトから取得した要素はVARIANT型のままです。
    これらの要素を既知のデータ型にキャストすることで、クエリのパフォーマンスが向上し、データ品質が改善されます。
    キャストには2つの方法があります：
        - CAST関数
        - 短縮構文: <source_expr> :: <target_data_type>

    以下は、これらのトピックを組み合わせて、メニューアイテム名、メニューアイテムID、
    必要な材料リストを取得するクエリです。
*/
SELECT
    menu_item_name,
    CAST(menu_item_health_metrics_obj:menu_item_id AS INTEGER) AS menu_item_id, -- 'AS'を使ったキャスト
    menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients::ARRAY AS ingredients -- ダブルコロン（::）構文を使ったキャスト
FROM raw_pos.menu_staging;

/*
    半構造化データを扱う際に活用できるもう一つの強力な関数がFLATTENです。
    FLATTENはJSONや配列などの半構造化データを展開し、
    指定されたオブジェクト内の各要素に対して1行を生成します。

    これを使って、トラックで使用されるすべてのメニューの全材料リストを取得できます。
*/
SELECT
    i.value::STRING AS ingredient_name,
    m.menu_item_health_metrics_obj:menu_item_id::INTEGER AS menu_item_id
FROM
    raw_pos.menu_staging m,
    LATERAL FLATTEN(INPUT => m.menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients::ARRAY) i;

/*  3. ダイナミックテーブル
    **************************************************************
    ユーザーガイド:
    https://docs.snowflake.com/en/user-guide/dynamic-tables-about
    **************************************************************
    
    すべての材料を構造化フォーマットで保存し、個別にクエリ、フィルタ、分析できると便利です。
    しかし、フードトラックのフランチャイズは常に新しいメニューアイテムを追加しており、
    その多くはデータベースにまだ存在しないユニークな材料を使用しています。
    
    そこでダイナミックテーブルを使用します。これはデータ変換パイプラインを簡素化するための強力なツールです。
    ダイナミックテーブルが今回のユースケースに最適な理由は以下の通りです：
        - 宣言的構文で作成され、データは指定されたクエリによって定義されます。
        - 自動データリフレッシュにより、手動更新やカスタムスケジューリングなしでデータが常に最新に保たれます。
        - Snowflakeのダイナミックテーブルが管理するデータの鮮度は、ダイナミックテーブル自体だけでなく、
          それに依存する下流のデータオブジェクトにも適用されます。

    これらの機能を実際に確認するために、シンプルなダイナミックテーブルパイプラインを作成し、
    ステージングテーブルに新しいメニューアイテムを追加して自動リフレッシュを実演します。

    まず、材料用のダイナミックテーブルを作成します。
*/
CREATE OR REPLACE DYNAMIC TABLE harmonized.ingredient
    LAG = '1 minute'
    WAREHOUSE = 'TB_DE_WH'
AS
    SELECT
    ingredient_name,
    menu_ids
FROM (
    SELECT DISTINCT
        i.value::STRING AS ingredient_name, -- ユニークな材料値
        ARRAY_AGG(m.menu_item_id) AS menu_ids -- 材料が使用されているメニューIDの配列
    FROM
        raw_pos.menu_staging m,
        LATERAL FLATTEN(INPUT => menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients::ARRAY) i
    GROUP BY i.value::STRING
);

-- 材料のダイナミックテーブルが正常に作成されたことを確認
SELECT * FROM harmonized.ingredient;

/*
    サンドイッチトラック「Better Off Bread」が新しいメニューアイテム「バインミー」を導入しました。
    このメニューアイテムにはフランスパン、マヨネーズ、大根の漬物などの材料が含まれます。
    
    ダイナミックテーブルの自動リフレッシュ機能により、menu_stagingテーブルにこの新しいメニューアイテムを
    追加すると、自動的にingredientテーブルに反映されます。
*/
INSERT INTO raw_pos.menu_staging 
SELECT 
    10101,
    15, --トラックID
    'Sandwiches',
    'Better Off Bread', -- トラックブランド名
    157, --メニューアイテムID
    'Banh Mi', -- メニューアイテム名
    'Main',
    'Cold Option',
    9.0,
    12.0,
    PARSE_JSON('{
      "menu_item_health_metrics": [
        {
          "ingredients": [
            "French Baguette",
            "Mayonnaise",
            "Pickled Daikon",
            "Cucumber",
            "Pork Belly"
          ],
          "is_dairy_free_flag": "N",
          "is_gluten_free_flag": "N",
          "is_healthy_flag": "Y",
          "is_nut_free_flag": "Y"
        }
      ],
      "menu_item_id": 157
    }'
);

/*
    French Baguette、Pickled Daikonがingredientテーブルに表示されていることを確認します。
    「Query produced no results」と表示される場合は、ダイナミックテーブルがまだリフレッシュされていません。
    ダイナミックテーブルのラグ設定に合わせて最大1分お待ちください。
*/

SELECT * FROM harmonized.ingredient 
WHERE ingredient_name IN ('French Baguette', 'Pickled Daikon');

/* 4. ダイナミックテーブルを使ったシンプルなパイプライン

    次に、材料からメニューへのルックアップ用ダイナミックテーブルを作成します。これにより、
    どのメニューアイテムがどの材料を使用しているかを確認できます。そして、どのトラックに
    どの材料がどれだけ必要かを判断できます。
    このテーブルもダイナミックテーブルなので、menu_stagingテーブルに新しいメニューアイテムが
    追加されて新しい材料が使用された場合、自動的にリフレッシュされます。
*/
CREATE OR REPLACE DYNAMIC TABLE harmonized.ingredient_to_menu_lookup
    LAG = '1 minute'
    WAREHOUSE = 'TB_DE_WH'    
AS
SELECT
    i.ingredient_name,
    m.menu_item_health_metrics_obj:menu_item_id::INTEGER AS menu_item_id
FROM
    raw_pos.menu_staging m,
    LATERAL FLATTEN(INPUT => m.menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients) f
JOIN harmonized.ingredient i ON f.value::STRING = i.ingredient_name;

-- 材料からメニューへのルックアップテーブルが正常に作成されたことを確認
SELECT * 
FROM harmonized.ingredient_to_menu_lookup
ORDER BY menu_item_id;

/*
    次の2つのINSERTクエリを実行して、2022年1月27日にトラック#15でバインミー2個が注文された
    シミュレーションを行います。その後、トラック別の材料使用量を表示する別の下流ダイナミックテーブルを作成します。
*/
INSERT INTO raw_pos.order_header
SELECT 
    459520441, -- order_id
    15, -- truck_id
    1030, -- location id
    101565,
    null,
    200322900,
    TO_TIMESTAMP_NTZ('08:00:00', 'hh:mi:ss'),
    TO_TIMESTAMP_NTZ('14:00:00', 'hh:mi:ss'),
    null,
    TO_TIMESTAMP_NTZ('2022-01-27 08:21:08.000'), -- 注文タイムスタンプ
    null,
    'USD',
    14.00,
    null,
    null,
    14.00;
    
INSERT INTO raw_pos.order_detail
SELECT
    904745311, -- order_detail_id
    459520441, -- order_id
    157, -- menu_item_id
    null,
    0,
    2, -- 注文数量
    14.00,
    28.00,
    null;

/*
    次に、米国における各フードトラックの材料の月次使用量をまとめる別のダイナミックテーブルを作成します。
    これにより、材料の消費を追跡し、在庫の最適化、コスト管理、メニュー計画やサプライヤーとの関係に
    関する意思決定に役立てることができます。
    
    注文タイムスタンプから日付部分を抽出する2つの方法に注目してください：
      -> EXTRACT(<date part> FROM <datetime>) は、指定されたタイムスタンプから指定の日付部分を取り出します。
      EXTRACT関数で使用できる日付・時間部分は、YEAR、MONTH、DAY、HOUR、MINUTE、SECONDなどがあります。
      -> MONTH(<datetime>) は月のインデックス（1-12）を返します。YEAR(<datetime>)とDAY(<datetime>)も
      同様に年と日を返します。
*/

-- テーブルを作成
CREATE OR REPLACE DYNAMIC TABLE harmonized.ingredient_usage_by_truck 
    LAG = '2 minute'
    WAREHOUSE = 'TB_DE_WH'  
    AS 
    SELECT
        oh.truck_id,
        EXTRACT(YEAR FROM oh.order_ts) AS order_year,
        MONTH(oh.order_ts) AS order_month,
        i.ingredient_name,
        SUM(od.quantity) AS total_ingredients_used
    FROM
        raw_pos.order_detail od
        JOIN raw_pos.order_header oh ON od.order_id = oh.order_id
        JOIN harmonized.ingredient_to_menu_lookup iml ON od.menu_item_id = iml.menu_item_id
        JOIN harmonized.ingredient i ON iml.ingredient_name = i.ingredient_name
        JOIN raw_pos.location l ON l.location_id = oh.location_id
    WHERE l.country = 'United States'
    GROUP BY
        oh.truck_id,
        order_year,
        order_month,
        i.ingredient_name
    ORDER BY
        oh.truck_id,
        total_ingredients_used DESC;
/*
    新しく作成したingredient_usage_by_truckビューを使って、
    2022年1月のトラック#15の材料使用量を確認しましょう。
*/
SELECT
    truck_id,
    ingredient_name,
    SUM(total_ingredients_used) AS total_ingredients_used,
FROM
    harmonized.ingredient_usage_by_truck
WHERE
    order_month = 1 -- 月は1-12の数値で表されます
    AND truck_id = 15
GROUP BY truck_id, ingredient_name
ORDER BY total_ingredients_used DESC;

/*  5. 有向非巡回グラフ（DAG）によるパイプラインの可視化

    最後に、パイプラインの有向非巡回グラフ（DAG）を理解しましょう。
    DAGはデータパイプラインの可視化ツールです。複雑なデータワークフローを視覚的にオーケストレーションし、
    タスクが正しい順序で実行されることを確認できます。パイプライン内の各ダイナミックテーブルの
    ラグメトリクスと設定を確認したり、必要に応じてテーブルを手動でリフレッシュすることもできます。

    DAGにアクセスするには：
    - ナビゲーションメニューの「Data」ボタンをクリックしてデータベース画面を開きます
    - 「TB_101」の横の矢印「>」をクリックしてデータベースを展開します
    - 「HARMONIZED」を展開し、「Dynamic Tables」を展開します
    - 「INGREDIENT」テーブルをクリックします
*/

-------------------------------------------------------------------------
--リセット--
-------------------------------------------------------------------------
USE ROLE accountadmin;
-- ダイナミックテーブルを削除
DROP TABLE IF EXISTS raw_pos.menu_staging;
DROP TABLE IF EXISTS harmonized.ingredient;
DROP TABLE IF EXISTS harmonized.ingredient_to_menu_lookup;
DROP TABLE IF EXISTS harmonized.ingredient_usage_by_truck;

-- 挿入データを削除
DELETE FROM raw_pos.order_detail
WHERE order_detail_id = 904745311;
DELETE FROM raw_pos.order_header
WHERE order_id = 459520441;

-- クエリタグを解除
ALTER SESSION UNSET query_tag;
-- ウェアハウスをサスペンド
ALTER WAREHOUSE tb_de_wh SUSPEND;

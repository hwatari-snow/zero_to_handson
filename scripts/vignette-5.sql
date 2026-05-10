/***************************************************************************************************       
Asset:        Zero to Snowflake - アプリとコラボレーション
Version:      v2     
Copyright(c): 2025 Snowflake Inc. All rights reserved.
****************************************************************************************************

アプリとコラボレーション
1. Snowflake Marketplaceから気象データを取得する
2. アカウントデータとWeather Sourceデータの統合 
3. Safegraph POIデータの探索
4. Streamlit in Snowflakeの紹介

****************************************************************************************************/

-- まず、セッションのQuery Tagを設定する
ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "apps_and_collaboration"}}';

-- ワークシートのコンテキストを設定する
USE DATABASE tb_101;
USE ROLE accountadmin;
USE WAREHOUSE tb_de_wh;

/*  1. Snowflake Marketplaceから気象データを取得する
    ***********************************************************
    ユーザーガイド:
    https://docs.snowflake.com/en/user-guide/data-sharing-intro
    ***********************************************************
    ジュニアアナリストのBenは、天候が米国のフードトラック売上にどのような影響を与えるかについて、より深い洞察を得たいと考えています。
    そのために、Snowflake Marketplaceを使用してアカウントに気象データを追加し、TastyBytesの自社データと突き合わせてクエリすることで、
    まったく新しいインサイトを発見します。
    
    Snowflake Marketplaceは、さまざまなサードパーティのデータ、アプリケーション、AI製品を発見してアクセスできる集約型ハブを提供します。
    このセキュアなデータ共有により、データの重複なしに、すぐにクエリ可能なライブデータにアクセスできます。
    
    Weather Sourceデータを取得する手順:
    1. アカウントレベルでaccountadminを使用していることを確認します（左下隅を確認）。
    2. ナビゲーションメニューから「Data Products」ページに移動します。新しいブラウザタブで開くことも可能です。
    3. 検索バーに「Weather Source frostbyte」と入力します。
    4. 「Weather Source LLC: frostbyte」リスティングを選択し、「Get」をクリックします。
    5. 「Options」をクリックしてオプションセクションを展開します。
    6. データベース名を「ZTS_WEATHERSOURCE」に変更します。
    7. 「PUBLIC」にアクセスを付与します。
    8. 「Done」を押します。
    
    このプロセスにより、Weather Sourceデータにほぼ即座にアクセスできるようになります。従来のデータ複製やパイプラインの必要性を排除することで、
    アナリストはビジネスの質問から実用的な分析に直接移行できます。
    
    気象データがアカウントに追加されたので、TastyBytesのアナリストは既存のロケーションデータとの結合をすぐに開始できます。
*/

-- アナリストロールに切り替え
USE ROLE tb_analyst;

/*  2. アカウントデータとWeather Sourceデータの統合

    rawのロケーションデータとWeather Source共有データの整合化を始める前に、データ共有に直接クエリして、
    作業するデータの概要を把握しましょう。まず、気象データで利用可能な全都市のリストと、
    各都市の気象メトリクスを取得します。
*/
SELECT 
    DISTINCT city_name,
    AVG(max_wind_speed_100m_mph) AS avg_wind_speed_mph,
    AVG(avg_temperature_air_2m_f) AS avg_temp_f,
    AVG(tot_precipitation_in) AS avg_precipitation_in,
    MAX(tot_snowfall_in) AS max_snowfall_in
FROM zts_weathersource.onpoint_id.history_day
WHERE country = 'US'
GROUP BY city_name;

-- 次に、rawのcountryデータとWeather Sourceデータ共有の過去の日次気象データを結合するビューを作成します。
CREATE OR REPLACE VIEW harmonized.daily_weather_v
COMMENT = 'Weather Source Daily History filtered to Tasty Bytes supported Cities'
    AS
SELECT
    hd.*,
    TO_VARCHAR(hd.date_valid_std, 'YYYY-MM') AS yyyy_mm,
    pc.city_name AS city,
    c.country AS country_desc
FROM zts_weathersource.onpoint_id.history_day hd
JOIN zts_weathersource.onpoint_id.postal_codes pc
    ON pc.postal_code = hd.postal_code
    AND pc.country = hd.country
JOIN raw_pos.country c
    ON c.iso_country = hd.country
    AND c.city = hd.city_name;

/*
    Daily Weather Historyビューを使用して、Benは2022年2月のHamburgの平均日次気温を検索し、
    折れ線グラフとして可視化したいと考えています。

    結果ペインで「Chart」をクリックして結果をグラフィカルに可視化します。チャートビューの左側セクションで
    「Chart Type」を以下のように設定します:
    
        Chart Type: Line chart | X-Axis: DATE_VALID_STD | Y-Axis: AVERAGE_TEMP_F
*/
SELECT
    dw.country_desc,
    dw.city_name,
    dw.date_valid_std,
    AVG(dw.avg_temperature_air_2m_f) AS average_temp_f
FROM harmonized.daily_weather_v dw
WHERE dw.country_desc = 'Germany'
    AND dw.city_name = 'Hamburg'
    AND YEAR(date_valid_std) = 2022
    AND MONTH(date_valid_std) = 2 -- 2月
GROUP BY dw.country_desc, dw.city_name, dw.date_valid_std
ORDER BY dw.date_valid_std DESC;

/*
    日次気象ビューは非常にうまく機能しています！さらに一歩進めて、注文ビューと日次気象ビューを組み合わせた
    日次売上対気象ビューを作成しましょう。これにより、売上と気象条件の間のトレンドや関係性を発見できます。
*/
CREATE OR REPLACE VIEW analytics.daily_sales_by_weather_v
COMMENT = 'Daily Weather Metrics and Orders Data'
AS
WITH daily_orders_aggregated AS (
    SELECT
        DATE(o.order_ts) AS order_date,
        o.primary_city,
        o.country,
        o.menu_item_name,
        SUM(o.price) AS total_sales
    FROM
        harmonized.orders_v o
    GROUP BY ALL
)
SELECT
    dw.date_valid_std AS date,
    dw.city_name,
    dw.country_desc,
    ZEROIFNULL(doa.total_sales) AS daily_sales,
    doa.menu_item_name,
    ROUND(dw.avg_temperature_air_2m_f, 2) AS avg_temp_fahrenheit,
    ROUND(dw.tot_precipitation_in, 2) AS avg_precipitation_inches,
    ROUND(dw.tot_snowdepth_in, 2) AS avg_snowdepth_inches,
    dw.max_wind_speed_100m_mph AS max_wind_speed_mph
FROM
    harmonized.daily_weather_v dw
LEFT JOIN
    daily_orders_aggregated doa
    ON dw.date_valid_std = doa.order_date
    AND dw.city_name = doa.primary_city
    AND dw.country_desc = doa.country
ORDER BY 
    date ASC;

/*
    Benはこの日次売上対気象ビューを使用して、天候が売上にどのように影響するか（これまで未探索の関係性）を明らかにし、
    「シアトル市場で大量の降水は売上にどのような影響を与えるか？」のような質問に答え始めることができます。

    Chart Type: Bar chart | X-Axis: MENU_ITEM_NAME | Y-Axis: DAILY_SALES
*/
SELECT * EXCLUDE (city_name, country_desc, avg_snowdepth_inches, max_wind_speed_mph)
FROM analytics.daily_sales_by_weather_v
WHERE 
    country_desc = 'United States'
    AND city_name = 'Seattle'
    AND avg_precipitation_inches >= 1.0
ORDER BY date ASC;

/*  3. Safegraph POIデータの探索

    Benはフードトラックのロケーションにおける気象条件についてさらに詳しく知りたいと考えています。
    幸いなことに、SafegraphがSnowflake Marketplaceで無料のPOI（Point-of-Interest）データを提供しています。
    
    このデータリスティングを使用するには、先ほどの気象データと同様の手順に従います:
        1. アカウントレベルでaccountadminを使用していることを確認します（左下隅を確認）。
        2. ナビゲーションメニューから「Data Products」ページに移動します。新しいブラウザタブで開くことも可能です。
        3. 検索バーに「safegraph frostbyte」と入力します。
        4. 「Safegraph: frostbyte」リスティングを選択し、「Get」をクリックします。
        5. 「Options」をクリックしてオプションセクションを展開します。
        6. データベース名: 「ZTS_SAFEGRAPH」
        7. 「PUBLIC」にアクセスを付与します。
        8. 「Done」を押します。
    
    SafegraphのPOIデータをFrostbyteのような気象データセットと自社の `orders_v` テーブルと結合することで、
    高リスクのロケーションを特定し、外部要因による財務的影響を定量化できます。
*/
CREATE OR REPLACE VIEW harmonized.tastybytes_poi_v
AS 
SELECT 
    l.location_id,
    sg.postal_code,
    sg.country,
    sg.city,
    sg.iso_country_code,
    sg.location_name,
    sg.top_category,
    sg.category_tags,
    sg.includes_parking_lot,
    sg.open_hours
FROM raw_pos.location l
JOIN zts_safegraph.public.frostbyte_tb_safegraph_s sg 
    ON l.location_id = sg.location_id
    AND l.iso_country_code = sg.iso_country_code;

-- POIデータを気象データと突き合わせてクエリし、2022年の米国で平均風速が最も高い上位3ロケーションを検索します。
SELECT TOP 3
    p.location_id,
    p.city,
    p.postal_code,
    AVG(hd.max_wind_speed_100m_mph) AS average_wind_speed
FROM harmonized.tastybytes_poi_v AS p
JOIN
    zts_weathersource.onpoint_id.history_day AS hd
    ON p.postal_code = hd.postal_code
WHERE
    p.country = 'United States'
    AND YEAR(hd.date_valid_std) = 2022
GROUP BY p.location_id, p.city, p.postal_code
ORDER BY average_wind_speed DESC;

/*
    前のクエリのlocation_idを使用して、異なる気象条件下での売上パフォーマンスを直接比較したいと思います。
    CTE（共通テーブル式）を使用して、上記のクエリをサブクエリとして使い、平均風速が最も高い上位3ロケーションを特定し、
    それらの特定ロケーションの売上データを分析します。共通テーブル式は複雑なクエリを異なる小さなクエリに分割し、
    可読性とパフォーマンスを向上させるのに役立ちます。
    
    各トラックブランドの売上データを2つのバケットに分けます: その日の最大風速が20mph以下の「穏やかな日」と、
    20mphを超える「風の強い日」です。

    このビジネスへの影響は、ブランドの気象耐性を特定することです。これらの売上数値を並べて見ることで、
    どのブランドが「天候に強い」か、どのブランドが強風時に売上が大幅に落ちるかを即座に把握できます。
    これにより、脆弱なブランドへの「強風日」プロモーションの実施、在庫の調整、または
    ブランドのメニューをロケーションの典型的な天候により適切にマッチさせるための
    将来のトラック配置戦略の策定など、より情報に基づいた運営上の意思決定が可能になります。
*/
WITH TopWindiestLocations AS (
    SELECT TOP 3
        p.location_id
    FROM harmonized.tastybytes_poi_v AS p
    JOIN
        zts_weathersource.onpoint_id.history_day AS hd
        ON p.postal_code = hd.postal_code
    WHERE
        p.country = 'United States'
        AND YEAR(hd.date_valid_std) = 2022
    GROUP BY p.location_id, p.city, p.postal_code
    ORDER BY AVG(hd.max_wind_speed_100m_mph) DESC
)
SELECT
    o.truck_brand_name,
    ROUND(
        AVG(CASE WHEN hd.max_wind_speed_100m_mph <= 20 THEN o.order_total END),
    2) AS avg_sales_calm_days,
    ZEROIFNULL(ROUND(
        AVG(CASE WHEN hd.max_wind_speed_100m_mph > 20 THEN o.order_total END),
    2)) AS avg_sales_windy_days
FROM analytics.orders_v AS o
JOIN
    zts_weathersource.onpoint_id.history_day AS hd
    ON o.primary_city = hd.city_name
    AND DATE(o.order_ts) = hd.date_valid_std
WHERE o.location_id IN (SELECT location_id FROM TopWindiestLocations)
GROUP BY o.truck_brand_name
ORDER BY o.truck_brand_name;

/*----------------------------------------------------------------------------------
 リセットスクリプト
----------------------------------------------------------------------------------*/
USE ROLE accountadmin;

-- ビューの削除
DROP VIEW IF EXISTS harmonized.daily_weather_v;
DROP VIEW IF EXISTS analytics.daily_sales_by_weather_v;
DROP VIEW IF EXISTS harmonized.tastybytes_poi_v;

-- Query Tagの解除
ALTER SESSION UNSET query_tag;
-- ウェアハウスの一時停止
ALTER WAREHOUSE tb_de_wh SUSPEND;

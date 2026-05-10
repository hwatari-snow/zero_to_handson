/*************************************************************************************************** 
Asset:        Zero to Snowflake - AISQL Functions
Version:      v2     
Copyright(c): 2025 Snowflake Inc. All rights reserved.
****************************************************************************************************

AISQL Functions
1. SENTIMENT() を使用して、フードトラックの顧客レビューをPositive、Negative、Neutralとしてスコアリングおよびラベル付けする
2. AI_CLASSIFY() を使用して、レビューをFood QualityやService Experienceなどのテーマ別に分類する
3. EXTRACT_ANSWER() を使用して、レビューテキストから具体的な苦情や称賛を抽出する
4. AI_SUMMARIZE_AGG() を使用して、トラックブランド名ごとの顧客感情の簡潔な要約を生成する

****************************************************************************************************/

ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "aisql_functions"}}';

/*
    TastyBytesのデータアナリストとして、AISQL関数を活用して顧客レビューから
    インサイトを得ることを目的に、適切なコンテキストを設定します。
*/

USE ROLE tb_analyst;
USE DATABASE tb_101;
USE WAREHOUSE tb_analyst_wh;

/* 1. 大規模な感情分析
    ***************************************************************
    全フードトラックブランドの顧客感情を分析し、最もパフォーマンスの高い
    トラックを特定し、フリート全体の顧客満足度メトリクスを作成します。
    Cortex Playgroundでは個別のレビューを手動で分析しました。ここでは
    SENTIMENT() 関数を使用して、顧客レビューを-1（ネガティブ）から+1（ポジティブ）で
    自動的にスコアリングし、Snowflakeの公式感情スコア範囲に従います。
    ***************************************************************/

-- ビジネス上の質問: 「各トラックブランドに対する顧客の全体的な感情はどうか？」
-- このクエリを実行して、フードトラックネットワーク全体の顧客感情を分析し、フィードバックを分類します

SELECT
    truck_brand_name,
    COUNT(*) AS total_reviews,
    AVG(CASE WHEN sentiment >= 0.5 THEN sentiment END) AS avg_positive_score,
    AVG(CASE WHEN sentiment BETWEEN -0.5 AND 0.5 THEN sentiment END) AS avg_neutral_score,
    AVG(CASE WHEN sentiment <= -0.5 THEN sentiment END) AS avg_negative_score
FROM (
    SELECT
        truck_brand_name,
        SNOWFLAKE.CORTEX.SENTIMENT (review) AS sentiment
    FROM harmonized.truck_reviews_v
    WHERE
        language ILIKE '%en%'
        AND review IS NOT NULL
    LIMIT 10000
)
GROUP BY
    truck_brand_name
ORDER BY total_reviews DESC;

/*
    重要なインサイト:
        Cortex Playgroundでレビューを1件ずつ分析していた状態から、数千件を体系的に
        処理する方法へと移行したことに注目してください。SENTIMENT() 関数がすべてのレビューを
        自動的にスコアリングし、Positive、Negative、Neutralに分類することで、
        フリート全体の顧客満足度メトリクスを即座に得ることができます。
    感情スコアの範囲:
        Positive:   0.5 〜 1
        Neutral:   -0.5 〜 0.5
        Negative:  -0.5 〜 -1
*/

/* 2. 顧客フィードバックの分類
    ***************************************************************
    次に、すべてのレビューを分類して、顧客がサービスのどの側面について
    最も多く言及しているかを把握します。AI_CLASSIFY() 関数を使用します。
    この関数は、単純なキーワードマッチングではなく、AIの理解に基づいて
    レビューをユーザー定義のカテゴリに自動分類します。このステップでは、
    顧客フィードバックをビジネスに関連する運用領域に分類し、その分布パターンを分析します。
    ***************************************************************/

-- ビジネス上の質問: 「顧客が主にコメントしているのは、料理の品質、サービス、それとも配達体験のどれか？」
-- 分類クエリを実行します:

WITH classified_reviews AS (
  SELECT
    truck_brand_name,
    AI_CLASSIFY(
      review,
      ['Food Quality', 'Pricing', 'Service Experience', 'Staff Behavior']
    ):labels[0] AS feedback_category
  FROM
    harmonized.truck_reviews_v
  WHERE
    language ILIKE '%en%'
    AND review IS NOT NULL
    AND LENGTH(review) > 30
  LIMIT
    10000
)
SELECT
  truck_brand_name,
  feedback_category,
  COUNT(*) AS number_of_reviews
FROM
  classified_reviews
GROUP BY
  truck_brand_name,
  feedback_category
ORDER BY
  truck_brand_name,
  number_of_reviews DESC;
                
/*
    重要なインサイト:
        AI_CLASSIFY() が数千件のレビューをFood Quality、Service Experienceなどの
        ビジネスに関連するテーマに自動分類したことに注目してください。Food Qualityが
        全トラックブランドで最も議論されているトピックであることが即座に確認でき、
        運用チームに顧客の優先事項に関する明確で実用的なインサイトを提供します。
*/

/* 3. 具体的な運用インサイトの抽出
    ***************************************************************
    次に、非構造化テキストから正確な回答を得るために、EXTRACT_ANSWER() 関数を
    活用します。この強力な関数により、顧客フィードバックに対して具体的なビジネス上の
    質問を投げかけ、直接的な回答を得ることができます。このステップでは、顧客レビューで
    言及されている具体的な運用上の問題を特定し、即座の対応が必要な問題を明らかにします。
    ***************************************************************/

-- ビジネス上の質問: 「各顧客レビューに含まれる具体的な運用上の問題やポジティブな言及は何か？」
-- 次のクエリを実行します:

  SELECT
    truck_brand_name,
    primary_city,
    LEFT(review, 100) || '...' AS review_preview,
    SNOWFLAKE.CORTEX.EXTRACT_ANSWER(
        review,
        'What specific improvement or complaint is mentioned in this review?'
    ) AS specific_feedback
FROM 
    harmonized.truck_reviews_v
WHERE 
    language = 'en'
    AND review IS NOT NULL
    AND LENGTH(review) > 50
ORDER BY truck_brand_name, primary_city ASC
LIMIT 10000;

/*
    重要なインサイト:
        EXTRACT_ANSWER() が長い顧客レビューから具体的で実用的なインサイトを抽出していることに
        注目してください。手動でレビューを確認する代わりに、この関数が「friendly staff was 
        saving grace」や「hot dogs are cooked to perfection」といった具体的なフィードバックを
        自動的に特定します。その結果、密度の高いテキストが、運用チームが即座に活用できる
        具体的で引用可能なフィードバックに変換されます。
*/

/* 4. エグゼクティブサマリーの生成
    ***************************************************************
    最後に、顧客フィードバックの簡潔な要約を作成するために、SUMMARIZE() 関数を使用します。
    この強力な関数は、長い非構造化テキストから短く一貫性のある要約を生成します。
    このステップでは、各トラックブランドの顧客レビューの本質を要約し、
    全体的な感情と主要ポイントの概要を迅速に把握できるようにします。
    ***************************************************************/

-- ビジネス上の質問: 「各トラックブランドの主要テーマと全体的な感情は何か？」
-- 要約クエリを実行します:

SELECT
  truck_brand_name,
  AI_SUMMARIZE_AGG (review) AS review_summary
FROM
  (
    SELECT
      truck_brand_name,
      review
    FROM
      harmonized.truck_reviews_v
    LIMIT
      100
  )
GROUP BY
  truck_brand_name;


/*
  重要なインサイト:
      AI_SUMMARIZE_AGG() 関数は、長いレビューを明確なブランドレベルの要約に凝縮します。
      これらの要約は繰り返し現れるテーマや感情のトレンドを強調し、意思決定者に
      各フードトラックのパフォーマンスの概要を迅速に提供し、個別のレビューを読まずに
      顧客の認識をより早く理解することを可能にします。
*/

/*************************************************************************************************** 
    AI SQL関数の変革的な力を成功裏に実証しました。個別レビューの処理から、体系的でプロダクション規模の
    インテリジェンスへと顧客フィードバック分析を進化させました。4つのコア関数を通じた我々の取り組みは、
    それぞれが異なる分析目的を果たし、生の顧客の声を包括的なビジネスインテリジェンスに変換することを
    明確に示しています — 体系的で、スケーラブルで、即座に実行可能です。かつて個別のレビュー分析を
    必要としたものが、今では数千件のレビューを数秒で処理し、データドリブンな運用改善に不可欠な
    感情的コンテキストと具体的な詳細の両方を提供します。
****************************************************************************************************/

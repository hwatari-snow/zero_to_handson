/***************************************************************************************************       
Asset:        Zero to Snowflake - Getting Started with Snowflake
Version:      v2     
Copyright(c): 2025 Snowflake Inc. All rights reserved.
****************************************************************************************************

Snowflakeの基本操作
1. 仮想ウェアハウスと設定
2. 永続化されたクエリ結果の活用
3. 基本的なデータ変換テクニック
4. UNDROPによるデータ復旧
5. リソースモニター
6. バジェット
7. ユニバーサル検索

****************************************************************************************************/

-- 始める前に、セッションのクエリタグを設定するために以下のクエリを実行してください。
ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "getting_started_with_snowflake"}}';

-- まずワークシートのコンテキストを設定します。データベース、スキーマ、ロールを指定します。

USE DATABASE tb_101;
USE ROLE accountadmin;

/*   1. 仮想ウェアハウスと設定
    **************************************************************
     ユーザーガイド:
     https://docs.snowflake.com/en/user-guide/warehouses-overview
    **************************************************************
    
    仮想ウェアハウスは、Snowflakeのデータ分析を実行するための動的でスケーラブル、
    かつコスト効率の高いコンピューティングリソースです。技術的な詳細を気にすることなく、
    すべてのデータ処理ニーズを処理することを目的としています。

    ウェアハウスのパラメータ:
      > WAREHOUSE_SIZE: 
            ウェアハウス内のクラスターごとに利用可能なコンピューティングリソースの量を指定します。
            X-Smallから6X-Largeまでのサイズが利用可能です。
            デフォルト: 'XSmall'
      > WAREHOUSE_TYPE:
            仮想ウェアハウスのタイプを定義し、アーキテクチャと動作を決定します。
            タイプ:
                'STANDARD' 汎用ワークロード向け
                'SNOWPARK_OPTIMIZED' メモリ集約型ワークロード向け
            デフォルト: 'STANDARD'
      > AUTO_SUSPEND:
            非アクティブ状態が続いた後、ウェアハウスが自動的にサスペンドされるまでの時間を指定します。
            デフォルト: 600秒
      > INITIALLY_SUSPENDED:
            ウェアハウスが作成直後にサスペンド状態で開始するかどうかを決定します。
            デフォルト: TRUE
      > AUTO_RESUME:
            クエリが送信された際に、サスペンド状態のウェアハウスを自動的に再開するかどうかを決定します。
            デフォルト: TRUE

        それでは、最初のウェアハウスを作成しましょう！
*/

-- まず、アカウント上に既に存在し、アクセス権限を持つウェアハウスを確認しましょう
SHOW WAREHOUSES;

/*
    ウェアハウスのリストとその属性（名前、状態（実行中またはサスペンド中）、タイプ、サイズなど）が
    返されます。
    
    Snowsightでもすべてのウェアハウスを表示・管理できます。ウェアハウスページにアクセスするには、
    ナビゲーションメニューの「Admin」ボタンをクリックし、展開されたAdminカテゴリ内の
    「Warehouses」リンクをクリックしてください。
    
    ウェアハウスページに戻ると、このアカウントのウェアハウスのリストとその属性が表示されます。
*/

-- シンプルなSQLコマンドで簡単にウェアハウスを作成できます
CREATE OR REPLACE WAREHOUSE my_wh
    COMMENT = 'My TastyBytes warehouse'
    WAREHOUSE_TYPE = 'standard'
    WAREHOUSE_SIZE = 'xsmall'
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'standard'
    AUTO_SUSPEND = 60
    INITIALLY_SUSPENDED = true
    AUTO_RESUME = false;

/*
    ウェアハウスを作成したので、このワークシートがこのウェアハウスを使用するように指定します。
    SQLコマンドまたはUIのいずれかで設定できます。
*/

-- ウェアハウスを使用する
USE WAREHOUSE my_wh;

/*
    シンプルなクエリを実行してみましょう。ただし、結果ペインにウェアハウスMY_WHがサスペンド中である
    旨のエラーメッセージが表示されます。今すぐ試してみてください。
*/
SELECT * FROM raw_pos.truck_details;

/*    
    クエリの実行およびすべてのDML操作にはアクティブなウェアハウスが必要です。
    データからインサイトを得るためには、ウェアハウスを再開する必要があります。
    
    エラーメッセージには、SQLコマンド 'ALTER warehouse MY_WH resume' を実行するよう
    提案も含まれていました。早速実行しましょう！
*/
ALTER WAREHOUSE my_wh RESUME;

/* 
    また、再びサスペンドした場合に手動で再開する必要がないよう、
    AUTO_RESUMEをTRUEに設定します。
 */
ALTER WAREHOUSE my_wh SET AUTO_RESUME = TRUE;

-- ウェアハウスが実行中になったので、先ほどのクエリを再度実行しましょう
SELECT * FROM raw_pos.truck_details;

-- これでデータに対してクエリを実行できるようになりました

/* 
    次に、Snowflakeにおけるウェアハウスのスケーラビリティの威力を見てみましょう。
    
    Snowflakeのウェアハウスはスケーラビリティと弾力性を備えて設計されており、
    ワークロードのニーズに応じてコンピューティングリソースを上下に調整できます。
    
    シンプルなALTER WAREHOUSE文で、ウェアハウスを即座にスケールアップできます。
*/
ALTER WAREHOUSE my_wh SET warehouse_size = 'XLarge';

-- トラックごとの売上を確認しましょう。
SELECT
    o.truck_brand_name,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(o.price) AS total_sales
FROM analytics.orders_v o
GROUP BY o.truck_brand_name
ORDER BY total_sales DESC;

/*
    結果パネルが開いた状態で、右上のツールバーを確認してください。検索、カラム選択、
    クエリ詳細と実行時間の統計、カラム統計、結果のダウンロードなどのオプションがあります。
    
    検索 - 検索語でフィルタリング
    カラム選択 - 結果に表示するカラムの有効/無効を切り替え
      クエリ詳細 - SQLテキスト、返された行数、クエリID、実行に使用されたロールと
      ウェアハウスなどのクエリ関連情報を含みます。
    クエリ実行時間 - コンパイル、プロビジョニング、実行時間ごとにクエリの所要時間を分類表示します。
    カラム統計 - 結果パネルのカラムの分布に関するデータを表示します。
    結果ダウンロード - 結果をCSVとしてエクスポート・ダウンロードします。
*/

/*  2. 永続化されたクエリ結果の活用
    *******************************************************************
    ユーザーガイド:
    https://docs.snowflake.com/en/user-guide/querying-persisted-results
    *******************************************************************
    
    次に進む前に、Snowflakeのもう一つの強力な機能であるクエリ結果キャッシュについて
    説明するのに良いタイミングです。
    
    先ほどのクエリを最初に実行した際、XLウェアハウスでも完了までに数秒かかりました。

    上記の「トラックごとの売上」クエリを再度実行し、クエリ実行時間ペインで合計実行時間を
    確認してください。最初の実行では数秒かかっていたのに対し、次の実行では数百ミリ秒程度に
    なっていることに気づくでしょう。これがクエリ結果キャッシュの効果です。

    クエリ履歴パネルを開き、最初の実行と2回目の実行の所要時間を比較してください。
    
    クエリ結果キャッシュの概要:
    - 結果は24時間保持されますが、クエリが実行されるたびにタイマーはリセットされます。
    - 結果キャッシュのヒットにはほとんどコンピューティングリソースを必要としないため、
      頻繁に実行されるレポートやダッシュボード、クレジット消費の管理に最適です。
    - キャッシュはCloud Services Layerに存在し、個別のウェアハウスとは論理的に分離されています。
      そのため、同じアカウント内のすべての仮想ウェアハウスとユーザーからグローバルにアクセス可能です。
*/

-- これからはより小さなデータセットで作業するため、ウェアハウスをスケールダウンします
ALTER WAREHOUSE my_wh SET warehouse_size = 'XSmall';

/*  3. 基本的な変換テクニック

    ウェアハウスが設定され実行中になったので、トラックのメーカーの分布を把握する計画です。
    ただし、この情報は'truck_build'という別のカラムに埋め込まれており、年式、メーカー、
    モデルの情報がVARIANTデータ型として格納されています。

    VARIANTデータ型は半構造化データの例です。OBJECT、ARRAY、その他のVARIANT値を含む
    あらゆる型のデータを格納できます。この場合、truck_buildには年式、メーカー、モデルの
    3つの異なるVARCHAR値を含む単一のOBJECTが格納されています。
    
    これから、3つのプロパティをそれぞれ独立したカラムに分離し、より簡単な分析を可能にします。
*/
SELECT truck_build FROM raw_pos.truck_details;

/*  ゼロコピークローニング

    truck_buildカラムのデータは一貫して同じ形式に従っています。'make'に対してより簡単に
    品質分析を行うために、別のカラムが必要です。計画としては、truckテーブルの開発用コピーを作成し、
    year、make、modelの新しいカラムを追加し、truck_build VARIANTオブジェクトから各プロパティを
    抽出してこれらの新しいカラムに格納します。
 
    Snowflakeの強力なゼロコピークローニングにより、追加のストレージスペースを使用せずに、
    データベースオブジェクトの同一で完全に機能する独立したコピーを即座に作成できます。

    ゼロコピークローニングはSnowflakeのユニークなマイクロパーティションアーキテクチャを活用して、
    クローンされたオブジェクトと元のコピー間でデータを共有します。いずれかのテーブルへの変更は、
    変更されたデータに対してのみ新しいマイクロパーティションが作成されます。これらの新しい
    マイクロパーティションは、クローンまたは元のクローン元オブジェクトのいずれかの所有者に
    専属的に所有されます。つまり、一方のテーブルに加えた変更は、もう一方には影響しません。
*/

-- truckテーブルのゼロコピークローンとしてtruck_devテーブルを作成
CREATE OR REPLACE TABLE raw_pos.truck_dev CLONE raw_pos.truck_details;

-- truckテーブルがtruck_devに正常にクローンされたことを確認
SELECT TOP 15 * 
FROM raw_pos.truck_dev
ORDER BY truck_id;

/*
    truckテーブルの開発用コピーができたので、新しいカラムの追加から始めましょう。
    注意: 3つのステートメントを一度に実行するには、それらを選択して画面右上の青い「Run」ボタンをクリックするか、キーボードを使用してください。
    
        Mac: command + return
        Windows: Ctrl + Enter
*/

ALTER TABLE raw_pos.truck_dev ADD COLUMN IF NOT EXISTS year NUMBER;
ALTER TABLE raw_pos.truck_dev ADD COLUMN IF NOT EXISTS make VARCHAR(255);
ALTER TABLE raw_pos.truck_dev ADD COLUMN IF NOT EXISTS model VARCHAR(255);

/*
    次に、truck_buildカラムから抽出したデータで新しいカラムを更新しましょう。
    コロン（:）演算子を使用してtruck_buildカラムの各キーの値にアクセスし、
    その値を対応するカラムに設定します。
*/
UPDATE raw_pos.truck_dev
SET 
    year = truck_build:year::NUMBER,
    make = truck_build:make::VARCHAR,
    model = truck_build:model::VARCHAR;

-- 3つのカラムが正常にテーブルに追加され、truck_buildから抽出されたデータが格納されたことを確認
SELECT year, make, model FROM raw_pos.truck_dev;

-- 異なるメーカーをカウントし、TastyBytesフードトラック車両のメーカー分布を把握しましょう。
SELECT 
    make,
    COUNT(*) AS count
FROM raw_pos.truck_dev
GROUP BY make
ORDER BY make ASC;

/*
    上記のクエリを実行した結果、データセットに問題があることに気づきます。一部のトラックのメーカーが
    'Ford'で、一部が'Ford_'となっており、同じトラックメーカーに対して2つの異なるカウントが出ています。
*/

-- まずUPDATEを使用して'Ford_'のすべての出現を'Ford'に変更します
UPDATE raw_pos.truck_dev
    SET make = 'Ford'
    WHERE make = 'Ford_';

-- makeカラムが正常に更新されたことを確認
SELECT truck_id, make 
FROM raw_pos.truck_dev
ORDER BY truck_id;

/*
    makeカラムが正しくなったので、truckテーブルとtruck_devテーブルをSWAPしましょう。
    このコマンドは2つのテーブル間のメタデータとデータをアトミックに交換し、
    truck_devテーブルを新しい本番truckテーブルとして即座に昇格させます。
*/
ALTER TABLE raw_pos.truck_details SWAP WITH raw_pos.truck_dev; 

-- 先ほどのクエリを実行して正確なメーカーカウントを取得
SELECT 
    make,
    COUNT(*) AS count
FROM raw_pos.truck_details
GROUP BY
    make
ORDER BY count DESC;
/*
    変更は問題ありません。データセットのクリーンアップを行います。まず、データを3つの別々のカラムに
    分割したので、本番データベースからtruck_buildカラムを削除します。
    その後、不要になったtruck_devテーブルを削除できます。
*/

-- シンプルなALTER TABLE ... DROP COLUMNコマンドで古いtruck_buildカラムを削除できます
ALTER TABLE raw_pos.truck_details DROP COLUMN truck_build;

-- truck_devテーブルを削除
DROP TABLE raw_pos.truck_details;

/*  4. UNDROPによるデータ復旧
	
    しまった！本番のtruckテーブルを誤って削除してしまいました。

    幸いなことに、UNDROPコマンドを使用して、削除される前の状態にテーブルを復元できます。
    UNDROPはSnowflakeの強力なTime Travel機能の一部であり、設定されたデータ保持期間
    （デフォルト24時間）内に削除されたデータベースオブジェクトの復元を可能にします。

    UNDROPを使用して本番の'truck'テーブルを早急に復元しましょう！
*/

-- オプション: このクエリを実行して'truck'テーブルがもう存在しないことを確認
    -- 注意: 'Table TRUCK does not exist or not authorized.'エラーはテーブルが削除されたことを意味します。
DESCRIBE TABLE raw_pos.truck_details;

-- 本番の'truck'テーブルにUNDROPを実行し、削除前の状態に復元
UNDROP TABLE raw_pos.truck_details;

-- テーブルが正常に復元されたことを確認
SELECT * from raw_pos.truck_details;

-- 本来のtruck_devテーブルを削除
DROP TABLE raw_pos.truck_dev;

/*  5. リソースモニター
    ***********************************************************
    ユーザーガイド:                                   
    https://docs.snowflake.com/en/user-guide/resource-monitors
    ***********************************************************

    クラウドベースのワークフローにおいて、コンピューティング使用量と支出の監視は非常に重要です。
    Snowflakeはリソースモニターを使用して、ウェアハウスのクレジット使用量を追跡する
    シンプルでわかりやすい方法を提供しています。

    リソースモニターでは、クレジットのクォータを定義し、定義した使用量の閾値に
    達した際に関連するウェアハウスに対して特定のアクションをトリガーします。

    リソースモニターが実行できるアクション:
    -NOTIFY: 指定されたユーザーまたはロールにメール通知を送信します。
    -SUSPEND: 閾値に達した際に関連するウェアハウスをサスペンドします。
              注意: 実行中のクエリは完了するまで継続されます。
    -SUSPEND_IMMEDIATE: 閾値に達した際に関連するウェアハウスをサスペンドし、
                        実行中のすべてのクエリをキャンセルします。

    それでは、ウェアハウスmy_wh用のリソースモニターを作成しましょう。

    まず、Snowsightでアカウントレベルのロールをaccountadminに設定しましょう。
    設定方法:
    - 画面左下のユーザーアイコンをクリック
    - 「Switch Role」にカーソルを合わせる
    - ロール一覧パネルから「ACCOUNTADMIN」を選択

   次に、ワークシートでaccountadminロールを使用します
*/
USE ROLE accountadmin;

-- 以下のクエリを実行してSQLでリソースモニターを作成
CREATE OR REPLACE RESOURCE MONITOR my_resource_monitor
    WITH CREDIT_QUOTA = 100
    FREQUENCY = MONTHLY -- DAILY、WEEKLY、YEARLY、またはNEVER（一回限りのクォータ）も指定可能
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS ON 75 PERCENT DO NOTIFY
             ON 90 PERCENT DO SUSPEND
             ON 100 PERCENT DO SUSPEND_IMMEDIATE;

-- リソースモニターが作成されたので、my_whに適用
ALTER WAREHOUSE my_wh 
    SET RESOURCE_MONITOR = my_resource_monitor;

/*  6. バジェット
    ****************************************************
      ユーザーガイド:                                   
      https://docs.snowflake.com/en/user-guide/budgets 
    ****************************************************
      
    前のステップでは、ウェアハウスのクレジット使用量を監視するリソースモニターを設定しました。
    このステップでは、Snowflakeのコスト管理に対するより包括的で柔軟なアプローチとして
    バジェットを作成します。
    
    リソースモニターがウェアハウスとコンピューティング使用量に特化しているのに対し、
    バジェットはあらゆるSnowflakeオブジェクトやサービスのコストを追跡し、支出制限を課し、
    金額が指定した閾値に達した際にユーザーに通知することができます。
*/

-- まずバジェットを作成しましょう
CREATE OR REPLACE SNOWFLAKE.CORE.BUDGET my_budget()
    COMMENT = 'My Tasty Bytes Budget';

/*
    バジェットを設定する前に、アカウントのメールアドレスを確認する必要があります。

    メールアドレスの確認方法:
    - 画面左下のユーザーアイコンをクリック
    - 「Settings」をクリック
    - メールフィールドにメールアドレスを入力
    - 「Save」をクリック
    - メールを確認し、指示に従って認証を完了
        注意: 数分経ってもメールが届かない場合は、「Resend Verification」をクリック
     
    新しいバジェットが作成され、メールが認証され、アカウントレベルのロールがaccountadminに
    設定されたので、Snowsightのバジェットページでバジェットにリソースを追加しましょう。

    Snowsightでバジェットページにアクセスする方法:
    - ナビゲーションメニューの「Admin」ボタンをクリック
    - 最初の項目「Cost Management」をクリック
    - 「Budgets」タブをクリック
    
    ウェアハウスの選択を求められた場合はtb_dev_whを選択し、それ以外の場合は
    画面右上のウェアハウスパネルでtb_dev_whが設定されていることを確認してください。
    
    バジェットページでは、現在の期間の支出に関するメトリクスが表示されます。
    画面中央には、現在の支出と予測支出のグラフが表示されます。
    画面下部には、先ほど作成した'MY_BUDGET'バジェットが表示されます。
    クリックしてバジェットページを表示してください。
    
    画面右上の「<- Budget Details」をクリックすると、バジェット詳細パネルが表示されます。
    ここでバジェットの情報と、それに関連付けられたすべてのリソースを確認できます。
    監視対象のリソースがないことがわかるので、今すぐ追加しましょう。
    「Edit」ボタンをクリックしてバジェット編集パネルを開きます。
    
    - バジェット名はそのまま
    - 支出上限を100に設定
    - 先ほど認証したメールアドレスを入力
    - 「+ Tags & Resources」ボタンをクリックしてリソースを追加
    - Databasesを展開し、TB_101を展開し、ANALYTICSスキーマの横のチェックボックスをオン
    - 下にスクロールして「Warehouses」を展開
    - 「TB_DE_WH」のチェックボックスをオン
    - 「Done」をクリック
    - バジェット編集メニューに戻り、「Save Changes」をクリック
*/

/*  7. ユニバーサル検索
    **************************************************************************
      ユーザーガイド                                                             
      https://docs.snowflake.com/en/user-guide/ui-snowsight-universal-search  
    **************************************************************************

    ユニバーサル検索を使用すると、アカウント内のあらゆるオブジェクトを簡単に検索でき、
    さらにMarketplaceのデータプロダクト、関連するSnowflakeドキュメント、
    Community Knowledge Baseの記事も探索できます。

    試してみましょう。
    - ユニバーサル検索を使用するには、ナビゲーションメニューの「Search」をクリック
    - ユニバーサル検索のUIが表示されます。最初の検索語を入力しましょう。
    - 検索バーに'truck'と入力し、結果を確認してください。上部のセクションは、
      データベース、テーブル、ビュー、ステージなど、アカウント上の関連オブジェクトの
      カテゴリです。データベースオブジェクトの下には、関連するMarketplaceのリスティングと
      ドキュメントのセクションが表示されます。

    - 自然言語で検索語を入力して、探しているものを説明することもできます。どのトラック
    フランチャイズのリピーター顧客が最も多いかを調べたい場合、「Which truck franchise has
    the most loyal customer base?」のように検索できます。「Tables & Views」セクションの横にある
    「View all >」ボタンをクリックすると、クエリに関連するすべてのテーブルとビューを表示できます。

    ユニバーサル検索は、異なるスキーマから複数のテーブルとビューを返します。各オブジェクトに
    関連するカラムがリストされていることにも注目してください。これらはすべて、リピーター顧客に
    ついてデータ駆動型の回答を得るための優れた出発点です。
*/

-------------------------------------------------------------------------
-- リセット --
-------------------------------------------------------------------------
-- 作成したオブジェクトを削除
DROP RESOURCE MONITOR IF EXISTS my_resource_monitor;
DROP TABLE IF EXISTS raw_pos.truck_dev;

-- truck_detailsをリセット
CREATE OR REPLACE TABLE raw_pos.truck_details
AS 
SELECT * EXCLUDE (year, make, model)
FROM raw_pos.truck;

DROP WAREHOUSE IF EXISTS my_wh;
-- クエリタグを解除
ALTER SESSION UNSET query_tag;
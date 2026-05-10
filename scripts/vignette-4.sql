/***************************************************************************************************       
Asset:        Zero to Snowflake - Governance with Horizon
Version:      v2     
Copyright(c): 2025 Snowflake Inc. All rights reserved.
****************************************************************************************************

Horizonによるガバナンス
1. ロールとアクセス制御の概要
2. 自動タグ付けによるタグベースの分類
3. マスキングポリシーによるカラムレベルセキュリティ
4. 行アクセスポリシーによる行レベルセキュリティ
5. データメトリック関数によるデータ品質モニタリング
6. Trust Centerによるアカウントセキュリティモニタリング

****************************************************************************************************/

-- セッションのクエリタグを設定
ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "governance_with_horizon"}}';

-- まずワークシートのコンテキストを設定します
USE ROLE useradmin;
USE DATABASE tb_101;
USE WAREHOUSE tb_dev_wh;

/*  1. ロールとアクセス制御の概要
    *************************************************************************
    ユーザーガイド:
    https://docs.snowflake.com/en/user-guide/security-access-control-overview
    *************************************************************************
    
    Snowflakeのアクセス制御フレームワークは以下に基づいています：
      - ロールベースアクセス制御（RBAC）: アクセス権限はロールに割り当てられ、ロールはユーザーに割り当てられます。
      - 任意アクセス制御（DAC）: 各オブジェクトには所有者がおり、所有者はそのオブジェクトへのアクセスを他者に付与できます。
    
    Snowflakeにおけるアクセス制御を理解するための主要な概念は以下の通りです：
      - セキュリティ保護可能オブジェクト: 誰が使用・閲覧できるかを制御できるものです。明示的に
        権限を付与されていない限り、アクセスできません。これらのオブジェクトは個人ではなく
        グループ（ロール）によって管理されます。データベース、テーブル、関数などが該当します。
      - ロール: ロールは付与できる権限のセットです。個々のユーザーや他のロールに付与でき、
        権限の連鎖を作成できます。
      - 権限: 権限はオブジェクトに対して何かを行うための具体的な許可です。多くの小さな権限を
        組み合わせて、アクセスの範囲を正確に制御できます。
      - ユーザー: ユーザーはSnowflakeが認識するID（ユーザー名など）です。実際の人間またはプログラムです。
    
      Snowflakeシステム定義ロールの説明：
       - ORGADMIN: 組織レベルの操作を管理するロール。
       - ACCOUNTADMIN: システムの最上位ロールであり、アカウント内の限られた数のユーザーにのみ付与すべきです。
       - SECURITYADMIN: オブジェクト権限をグローバルに管理し、ユーザーとロールの作成・監視・管理ができるロール。
       - USERADMIN: ユーザーとロールの管理専用のロール。
       - SYSADMIN: アカウント内でウェアハウスとデータベースを作成する権限を持つロール。
       - PUBLIC: PUBLICはすべてのユーザーとロールに自動的に付与される疑似ロールです。
           セキュリティ保護可能オブジェクトを所有でき、PUBLICが所有するものはアカウント内の
           すべてのユーザーとロールが利用可能になります。

                                +---------------+
                                | ACCOUNTADMIN  |
                                +---------------+
                                  ^    ^     ^
                                  |    |     |
                    +-------------+-+  |    ++-------------+
                    | SECURITYADMIN |  |    |   SYSADMIN   |<------------+
                    +---------------+  |    +--------------+             |
                            ^          |     ^        ^                  |
                            |          |     |        |                  |
                    +-------+-------+  |     |  +-----+-------+  +-------+-----+
                    |   USERADMIN   |  |     |  | CUSTOM ROLE |  | CUSTOM ROLE |
                    +---------------+  |     |  +-------------+  +-------------+
                            ^          |     |      ^              ^      ^
                            |          |     |      |              |      |
                            |          |     |      |              |    +-+-----------+
                            |          |     |      |              |    | CUSTOM ROLE |
                            |          |     |      |              |    +-------------+
                            |          |     |      |              |           ^
                            |          |     |      |              |           |
                            +----------+-----+---+--+--------------+-----------+
                                                 |
                                            +----+-----+
                                            |  PUBLIC  |
                                            +----------+

    このセクションでは、カスタムデータスチュワードロールを作成し、権限を関連付ける方法を見ていきます。
*/
-- まず、アカウントに既に存在するロールを確認しましょう。
SHOW ROLES;

-- データスチュワードロールを作成します。
CREATE OR REPLACE ROLE tb_data_steward
    COMMENT = 'Custom Role';
-- ロールが作成されたので、SECURITYADMINロールに切り替えて新しいロールに権限を付与します。

/*
    新しいロールが作成されたので、クエリを実行するためにウェアハウスを使用できるようにする必要があります。
    先に進む前に、ウェアハウスの権限について理解を深めましょう。
     
    - MODIFY: サイズの変更を含む、ウェアハウスのプロパティの変更を可能にします。
    - MONITOR: ウェアハウスで実行された現在と過去のクエリ、および使用統計の閲覧を可能にします。
    - OPERATE: ウェアハウスの状態変更（停止、開始、サスペンド、再開）を可能にします。
       加えて、実行中のクエリの閲覧と中止も可能です。
    - USAGE: 仮想ウェアハウスの使用、つまりウェアハウスでのクエリ実行を可能にします。
       ウェアハウスがSQL文の送信時に自動再開するよう設定されている場合、
       ウェアハウスは自動的に再開し、文を実行します。
    - ALL: OWNERSHIP以外のすべての権限をウェアハウスに付与します。

      ウェアハウスの権限を理解したので、新しいロールにOPERATEとUSAGE権限を付与できます。
      まず、SECURITYADMINロールに切り替えます。
*/
USE ROLE securityadmin;
-- まず、ウェアハウスtb_dev_whを使用する権限をロールに付与します
GRANT OPERATE, USAGE ON WAREHOUSE tb_dev_wh TO ROLE tb_data_steward;

/*
     次に、Snowflakeのデータベースとスキーマの権限について理解しましょう：
      - MODIFY: データベース設定の変更を可能にします。
      - MONITOR: DESCRIBEコマンドの実行を可能にします。
      - USAGE: データベースの使用を可能にします。SHOW DATABASESコマンド出力にデータベースの詳細を
         返すことも含みます。データベース内のオブジェクトを閲覧・操作するには追加の権限が必要です。
      - ALL: OWNERSHIP以外のすべての権限をデータベースに付与します。
*/

GRANT USAGE ON DATABASE tb_101 TO ROLE tb_data_steward;
GRANT USAGE ON ALL SCHEMAS IN DATABASE tb_101 TO ROLE tb_data_steward;

/*
    Snowflakeのテーブルとビュー内のデータへのアクセスは、以下の権限で管理されます：
        SELECT: データの取得を許可します。
        INSERT: 新しい行の追加を許可します。
        UPDATE: 既存の行の変更を許可します。
        DELETE: 行の削除を許可します。
        TRUNCATE: テーブル内のすべての行の削除を許可します。

      次に、raw_customerスキーマのテーブルに対してSELECTクエリを実行できるようにします。
*/

-- RAW_CUSTOMERスキーマのすべてのテーブルにSELECT権限を付与
GRANT SELECT ON ALL TABLES IN SCHEMA raw_customer TO ROLE tb_data_steward;
-- governanceスキーマとそのすべてのテーブルにALL権限を付与
GRANT ALL ON SCHEMA governance TO ROLE tb_data_steward;
GRANT ALL ON ALL TABLES IN SCHEMA governance TO ROLE tb_data_steward;

/*
    新しいロールを使用するには、現在のユーザーにロールを付与する必要があります。
    次の2つのクエリを実行して、現在のユーザーに新しいデータスチュワードロールの使用権限を付与します。
*/
SET my_user = CURRENT_USER();
GRANT ROLE tb_data_steward TO USER IDENTIFIER($my_user);

/*
    最後に、以下のクエリを実行して新しく作成したロールを使用しましょう！
    --> または、ワークシートUIの「Select role and warehouse」ボタンをクリックし、
        「tb_data_steward」を選択することでもロールを使用できます。
*/
USE ROLE tb_data_steward;

-- お祝いに、これから扱うデータの種類を確認しましょう。
SELECT TOP 100 * FROM raw_customer.customer_loyalty;

/*
    顧客ロイヤルティデータが表示されています。しかし、よく見ると、このテーブルには
    機密性の高い個人識別情報（PII）が多数含まれていることが明らかです。
    次のセクションでは、これをどのように軽減するかを詳しく見ていきます。
*/

/*  2. 自動タグ付けによるタグベースの分類
    ******************************************************
    ユーザーガイド:
    https://docs.snowflake.com/en/user-guide/classify-auto
    ******************************************************

    前回のクエリで、Customer Loyaltyテーブルにかなりの個人識別情報（PII）が保存されている
    ことに気づきました。Snowflakeの自動タグ付け機能とタグベースのマスキングを組み合わせて、
    クエリ結果の機密データを難読化できます。

    Snowflakeはデータベーススキーマ内のカラムを継続的に監視することで、機密情報を自動的に
    検出してタグ付けできます。データエンジニアがスキーマに分類プロファイルを割り当てると、
    そのスキーマのテーブル内のすべての機密データがプロファイルのスケジュールに基づいて
    自動的に分類されます。
    
    これから分類プロファイルを作成し、カラムのセマンティックカテゴリに基づいて自動的に
    割り当てられるタグを指定します。まずaccountadminロールに切り替えましょう。
*/
USE ROLE accountadmin;

/*
    governanceスキーマを作成し、その中にPII用のタグを作成し、データベースオブジェクトに
    タグを適用する権限を新しいロールに付与します。
*/
CREATE OR REPLACE TAG governance.pii;
GRANT APPLY TAG ON ACCOUNT TO ROLE tb_data_steward;

/*
    まず、tb_data_stewardロールにデータ分類の実行とraw_customerスキーマでの
    分類プロファイル作成に必要な権限を付与します。
*/
GRANT EXECUTE AUTO CLASSIFICATION ON SCHEMA raw_customer TO ROLE tb_data_steward;
GRANT DATABASE ROLE SNOWFLAKE.CLASSIFICATION_ADMIN TO ROLE tb_data_steward;
GRANT CREATE SNOWFLAKE.DATA_PRIVACY.CLASSIFICATION_PROFILE ON SCHEMA governance TO ROLE tb_data_steward;

-- データスチュワードロールに切り替えます。
USE ROLE tb_data_steward;

/*
    分類プロファイルを作成します。スキーマに追加されたオブジェクトは即座に分類され、
    30日間有効で、自動的にタグ付けされます。
*/
CREATE OR REPLACE SNOWFLAKE.DATA_PRIVACY.CLASSIFICATION_PROFILE
  governance.tb_classification_profile(
    {
      'minimum_object_age_for_classification_days': 0,
      'maximum_classification_validity_days': 30,
      'auto_tag': true
    });

/*
    指定されたセマンティックカテゴリに基づいてカラムに自動的にタグを付けるタグマップを作成します。
    semantic_categories配列のいずれかの値で分類されたカラムは、自動的にPIIタグが付与されます。
*/
CALL governance.tb_classification_profile!SET_TAG_MAP(
  {'column_tag_map':[
    {
      'tag_name':'tb_101.governance.pii',
      'tag_value':'pii',
      'semantic_categories':['NAME', 'PHONE_NUMBER', 'POSTAL_CODE', 'DATE_OF_BIRTH', 'CITY', 'EMAIL']
    }]});

-- SYSTEM$CLASSIFYを呼び出して、分類プロファイルを使用してcustomer_loyaltyテーブルを自動分類します。
CALL SYSTEM$CLASSIFY('tb_101.raw_customer.customer_loyalty', 'tb_101.governance.tb_classification_profile');

/*
    次のクエリを実行して、自動分類とタグ付けの結果を確認します。すべてのSnowflakeアカウントで
    利用可能なINFORMATION_SCHEMAからメタデータを取得します。各カラムがどのようにタグ付けされ、
    前のステップで作成した分類プロファイルとどのように関連しているか確認してください。
    
    すべてのカラムにPRIVACY_CATEGORYとSEMANTIC_CATEGORYタグが付与されていることがわかります。
    PRIVACY_CATEGORYはカラム内の個人データの機密レベルを示し、
    SEMANTIC_CATEGORYはデータが表す現実世界の概念を示します。
    
    最後に、分類タグマップ配列で指定したセマンティックカテゴリでタグ付けされたカラムには、
    カスタム「PII」タグが付与されていることに注目してください。
*/
SELECT 
    column_name,
    tag_database,
    tag_schema,
    tag_name,
    tag_value,
    apply_method
FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('raw_customer.customer_loyalty', 'table'));

/*  3. マスキングポリシーによるカラムレベルセキュリティ
    **************************************************************
    ユーザーガイド:
    https://docs.snowflake.com/en/user-guide/security-column-intro
    **************************************************************

    Snowflakeのカラムレベルセキュリティでは、マスキングポリシーを使用してカラム内のデータを保護できます。
    主に2つの機能があります：ダイナミックデータマスキング（クエリ時に機密データを非表示または変換）と、
    外部トークン化（Snowflakeに入る前にデータをトークン化し、クエリ時にデトークン化）です。

    機密カラムがPIIとしてタグ付けされたので、そのタグに関連付けるマスキングポリシーを作成します。
    1つ目は氏名、メールアドレス、電話番号などの機密文字列データ用です。
    2つ目は生年月日などの機密DATE値用です。

    両方のマスキングロジックは類似しています：現在のロールがPIIタグ付きカラムをクエリし、
    アカウント管理者またはTastyBytes管理者でない場合、文字列値は「MASKED」と表示されます。
    DATE値は元の年のみが表示され、月と日は01-01になります。
*/

-- 機密文字列データ用のマスキングポリシーを作成
CREATE OR REPLACE MASKING POLICY governance.mask_string_pii AS (original_value STRING)
RETURNS STRING ->
  CASE WHEN
    -- ユーザーの現在のロールが特権ロールでない場合、カラムをマスクする。
    CURRENT_ROLE() NOT IN ('ACCOUNTADMIN', 'TB_ADMIN')
    THEN '****MASKED****'
    -- それ以外（タグが機密でないか、ロールが特権ロール）の場合、元の値を表示する。
    ELSE original_value
  END;

-- 機密DATEデータ用のマスキングポリシーを作成
CREATE OR REPLACE MASKING POLICY governance.mask_date_pii AS (original_value DATE)
RETURNS DATE ->
  CASE WHEN
    CURRENT_ROLE() NOT IN ('ACCOUNTADMIN', 'TB_ADMIN')
    THEN DATE_TRUNC('year', original_value) -- マスク時は年のみ変更されず、月と日は01-01になる
    ELSE original_value
  END;

-- 両方のマスキングポリシーを、customer loyaltyテーブルに自動的に適用されたタグに紐付ける
ALTER TAG governance.pii SET
    MASKING POLICY governance.mask_string_pii,
    MASKING POLICY governance.mask_date_pii;

/*
    publicロールに切り替え、customer loyaltyテーブルの最初の100行をクエリして、
    マスキングポリシーが機密データをどのように難読化するか観察します。
*/
USE ROLE public;
SELECT TOP 100 * FROM raw_customer.customer_loyalty;

-- TB_ADMINロールに切り替えて、管理者ロールにはマスキングポリシーが適用されないことを確認
USE ROLE tb_admin;
SELECT TOP 100 * FROM raw_customer.customer_loyalty;

/*  4. 行アクセスポリシーによる行レベルセキュリティ
    ***********************************************************
    ユーザーガイド:
    https://docs.snowflake.com/en/user-guide/security-row-intro
    ***********************************************************

    Snowflakeは行アクセスポリシーを使用して行レベルセキュリティをサポートし、
    クエリ結果にどの行を返すかを決定します。ポリシーはテーブルに紐付けられ、
    定義したルールに基づいて各行を評価します。これらのルールは、クエリを実行する
    ユーザーの属性（現在のロールなど）を使用することが多いです。

    例えば、行アクセスポリシーを使用して、米国のユーザーが米国内の顧客データのみを
    閲覧できるようにすることができます。

    まず、データスチュワードロールに切り替えましょう。
*/
USE ROLE tb_data_steward;

-- 行アクセスポリシーを作成する前に、行ポリシーマップを作成します。
CREATE OR REPLACE TABLE governance.row_policy_map
    (role STRING, country_permission STRING);

/*
    行ポリシーマップは、ロールと許可されるアクセス行の値を関連付けます。
    例えば、tb_data_engineerロールを国の値「United States」に関連付けると、
    tb_data_engineerは国の値が「United States」の行のみを閲覧できます。
*/
INSERT INTO governance.row_policy_map
    VALUES('tb_data_engineer', 'United States');

/*
    行ポリシーマップが準備できたので、行アクセスポリシーを作成します。
    
    このポリシーは、管理者は行アクセスに制限がなく、ポリシーマップ内の他のロールは
    関連付けられた国に一致する行のみを閲覧できることを定めています。
*/
CREATE OR REPLACE ROW ACCESS POLICY governance.customer_loyalty_policy
    AS (country STRING) RETURNS BOOLEAN ->
        CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN') 
        OR EXISTS 
            (
            SELECT 1
                FROM governance.row_policy_map rp
            WHERE
                UPPER(rp.role) = CURRENT_ROLE()
                AND rp.country_permission = country
            );

-- 行アクセスポリシーをcustomer loyaltyテーブルの「country」カラムに適用
ALTER TABLE raw_customer.customer_loyalty
    ADD ROW ACCESS POLICY governance.customer_loyalty_policy ON (country);

/*
    次に、行ポリシーマップで「United States」に関連付けたロールに切り替え、
    行アクセスポリシーが適用されたテーブルをクエリした結果を観察します。
*/
USE ROLE tb_data_engineer;

-- 米国の顧客のみが表示されるはずです。
SELECT TOP 100 * FROM raw_customer.customer_loyalty;

/*
    お疲れ様でした！Snowflakeのカラムレベルおよび行レベルセキュリティ戦略を使って
    データをガバナンスし保護する方法について理解が深まったはずです。タグを使用して
    マスキングポリシーと連携し、個人識別情報を含むカラムを保護する方法と、
    行アクセスポリシーを使ってロールが特定のカラム値にのみアクセスできるようにする方法を学びました。
*/

/*  5. データメトリック関数によるデータ品質モニタリング
    ***********************************************************
    ユーザーガイド:
    https://docs.snowflake.com/en/user-guide/data-quality-intro
    ***********************************************************

    Snowflakeはデータメトリック関数（DMF）を使用してデータの一貫性と信頼性を維持します。
    これはプラットフォーム内で直接品質チェックを自動化するための強力な機能です。
    任意のテーブルやビューにこれらのチェックをスケジュールすることで、データの整合性を
    明確に把握でき、より信頼性の高いデータに基づく意思決定が可能になります。
    
    Snowflakeは即座に使用可能なシステムDMFと、独自のビジネスロジック用のカスタムDMFを
    作成する柔軟性の両方を提供し、包括的な品質モニタリングを実現します。

    システムDMFをいくつか見てみましょう！
*/

-- TastyBytesデータスチュワードロールに切り替えてDMFの使用を開始します
USE ROLE tb_data_steward;

-- order_headerテーブルのcustomer_idのNULL割合を返します。
SELECT SNOWFLAKE.CORE.NULL_PERCENT(SELECT customer_id FROM raw_pos.order_header);

-- DUPLICATE_COUNTを使用して重複するorder_idをチェックできます。
SELECT SNOWFLAKE.CORE.DUPLICATE_COUNT(SELECT order_id FROM raw_pos.order_header); 

-- 全注文の平均注文合計金額
SELECT SNOWFLAKE.CORE.AVG(SELECT order_total FROM raw_pos.order_header);

/*
    特定のビジネスルールに従ってデータ品質を監視するカスタムデータメトリック関数も作成できます。
    注文合計が単価×数量と一致しない注文をチェックするカスタムDMFを作成します。
*/

-- カスタムデータメトリック関数を作成
CREATE OR REPLACE DATA METRIC FUNCTION governance.invalid_order_total_count(
    order_prices_t table(
        order_total NUMBER,
        unit_price NUMBER,
        quantity INTEGER
    )
)
RETURNS NUMBER
AS
'SELECT COUNT(*)
 FROM order_prices_t
 WHERE order_total != unit_price * quantity';

-- 合計が単価×数量と一致しない新しい注文をシミュレート
INSERT INTO raw_pos.order_detail
SELECT
    904745311,
    459520442,
    52,
    null,
    0,
    2, -- 数量
    5.0, -- 単価
    5.0, -- 合計金額（意図的に不正確）
    null;

-- カスタムDMFをorder_detailテーブルに対して呼び出す。
SELECT governance.invalid_order_total_count(
    SELECT 
        price, 
        unit_price, 
        quantity 
    FROM raw_pos.order_detail
) AS num_orders_with_incorrect_price;

-- order_detailテーブルにデータメトリックスケジュールを設定（変更時にトリガー）
ALTER TABLE raw_pos.order_detail
    SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

-- カスタムDMFをテーブルに割り当て
ALTER TABLE raw_pos.order_detail
    ADD DATA METRIC FUNCTION governance.invalid_order_total_count
    ON (price, unit_price, quantity);

/*  6. Trust Centerによるアカウントセキュリティモニタリング
    **************************************************************
    ユーザーガイド:
    https://docs.snowflake.com/en/user-guide/trust-center/overview
    **************************************************************

    Trust Centerは、スキャナーを使用してアカウントのセキュリティリスクを自動的にチェック・
    評価・監視する機能です。スキャナーは、アカウントのセキュリティリスクや違反をチェックする
    スケジュールされたバックグラウンドプロセスであり、検出結果に基づいて推奨アクションを
    提供します。スキャナーは通常、スキャナーパッケージとしてグループ化されています。
    
    Trust Centerの一般的なユースケース：
        - ユーザーの多要素認証が有効になっていることの確認
        - 過剰な権限を持つロールの発見
        - 90日以上ログインしていない非アクティブユーザーの発見
        - リスクのあるユーザーの発見と軽減

    始める前に、管理者ロールにTrust Centerの管理者となるために必要な権限を付与します。
*/
USE ROLE accountadmin;
GRANT APPLICATION ROLE SNOWFLAKE.TRUST_CENTER_ADMIN TO ROLE tb_admin;
USE ROLE tb_admin; -- TastyBytes管理者ロールに切り替え

/*
    ナビゲーションメニューで「Governance & security」にカーソルを合わせ、
    「Trust Center」をクリックします。必要であれば別のブラウザタブで開くこともできます。
    Trust Centerを最初にロードすると、いくつかのペインとセクションが表示されます：
        1. タブ: Findings、Scanner Packages
        2. パスワード準備状況ペイン
        3. 未解決のセキュリティ違反
        4. フィルター付きの違反リスト

    タブの下にCIS Benchmarksスキャナーパッケージの有効化を促すメッセージが表示される場合があります。
    次のステップでそれを行います。

    「Scanner Packages」タブをクリックします。ここにスキャナーパッケージのリストが表示されます。
    これらはスキャナーのグループで、アカウントのセキュリティリスクをチェックするスケジュールされた
    バックグラウンドプロセスです。各スキャナーパッケージには、名前、プロバイダー、
    アクティブ・非アクティブなスキャナーの数、ステータスが表示されます。
    Security Essentialsスキャナーパッケージを除き、すべてのスキャナーパッケージはデフォルトで無効です。
    
    「CIS Benchmarks」をクリックしてスキャナーパッケージの詳細を確認します。
    パッケージの名前と説明、有効化オプションが表示されます。その下にスキャナーパッケージ内の
    スキャナーリストがあります。各スキャナーをクリックすると、スケジュール、最終実行日時、
    説明などの詳細が表示されます。

    「Enable Package」ボタンをクリックして有効にしましょう。「Enable Scanner Package」
    モーダルが表示され、スキャナーパッケージのスケジュールを設定できます。
    月次スケジュールで実行するよう設定しましょう。

    「Frequency」のドロップダウンをクリックし、「Monthly」オプションを選択します。
    その他の値はそのままにします。パッケージは有効化時および設定されたスケジュールで
    自動的に実行されることに注意してください。
    
    オプションで通知設定を構成できます。最小重大度トリガーレベルが「Critical」で、
    受信者に「Admin users」が選択されているデフォルト値のままで問題ありません。
    「continue」を押します。
    スキャナーパッケージが完全に有効になるまで数秒かかる場合があります。

    「Threat Intelligence」スキャナーパッケージについても同様に繰り返しましょう。
    前のスキャナーパッケージと同じ設定を使用します。
    
    両方のパッケージが有効になったら、「Findings」タブに戻り、
    スキャナーパッケージが検出した違反を確認します。

    違反リストにより多くのエントリが表示され、各重大度レベルの違反数のグラフが
    表示されるはずです。違反リストでは、簡単な説明、重大度、スキャナーパッケージなど、
    各違反の詳細情報を確認できます。違反を解決済みとしてマークするオプションもあります。
    さらに、個々の違反をクリックすると、違反の要約や修復オプションなどの詳細情報を
    含む詳細ペインが表示されます。

    違反リストは、ドロップダウンオプションを使用してステータス、重大度、
    スキャナーパッケージでフィルタリングできます。
    違反グラフの重大度カテゴリをクリックすると、そのタイプのフィルターも適用されます。
    
    現在アクティブなフィルターカテゴリの横にある「X」をクリックしてフィルターを解除します。
*/

-------------------------------------------------------------------------
--リセット--
-------------------------------------------------------------------------
USE ROLE accountadmin;

-- データスチュワードロールを削除
DROP ROLE IF EXISTS tb_data_steward;

-- マスキングポリシー
ALTER TAG IF EXISTS governance.pii UNSET
    MASKING POLICY governance.mask_string_pii,
    MASKING POLICY governance.mask_date_pii;
DROP MASKING POLICY IF EXISTS governance.mask_string_pii;
DROP MASKING POLICY IF EXISTS governance.mask_date_pii;

-- 自動分類
ALTER SCHEMA raw_customer UNSET CLASSIFICATION_PROFILE;
DROP SNOWFLAKE.DATA_PRIVACY.CLASSIFICATION_PROFILE IF EXISTS tb_classification_profile;

-- 行アクセスポリシー
ALTER TABLE raw_customer.customer_loyalty 
    DROP ROW ACCESS POLICY governance.customer_loyalty_policy;
DROP ROW ACCESS POLICY IF EXISTS governance.customer_loyalty_policy;

-- データメトリック関数
DELETE FROM raw_pos.order_detail WHERE order_detail_id = 904745311;
ALTER TABLE raw_pos.order_detail
    DROP DATA METRIC FUNCTION governance.invalid_order_total_count ON (price, unit_price, quantity);
DROP FUNCTION governance.invalid_order_total_count(TABLE(NUMBER, NUMBER, INTEGER));
ALTER TABLE raw_pos.order_detail UNSET DATA_METRIC_SCHEDULE;

-- タグを解除
ALTER TABLE raw_customer.customer_loyalty
  MODIFY
    COLUMN first_name UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN last_name UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN e_mail UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN phone_number UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN postal_code UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN marital_status UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN gender UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN birthday_date UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN country UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN city UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY;

-- PIIタグを削除
DROP TAG IF EXISTS governance.pii;
-- クエリタグを解除
ALTER SESSION UNSET query_tag;
ALTER WAREHOUSE tb_dev_wh SUSPEND;

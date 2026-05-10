# Streamlit in Snowflake へようこそ！

# 必要なライブラリのインポート
# streamlit はWebアプリのインターフェース作成に使用します。
import streamlit as st
# pandas はデータの操作と分析に使用します。
import pandas as pd
# altair はインタラクティブなデータ可視化の作成に使用します。
import altair as alt
# snowflake.snowpark.context はSnowflakeへの接続とアクティブセッションの取得に使用します。
from snowflake.snowpark.context import get_active_session

# --- アプリのセットアップとデータ読み込み ---

# Snowflakeと連携するためのアクティブなSnowparkセッションを取得します。
session = get_active_session()

# Streamlitアプリケーションのタイトルを設定します。ページの上部に表示されます。
st.title("Menu Item Sales in Japan for February 2022")

st.write('---') # 区切り線を作成します

# Snowflakeからデータを読み込む関数を定義します。
# @st.cache_data はStreamlitのデコレータで、この関数の出力をキャッシュします。
# これにより、データはSnowflakeから一度だけ取得され、
# 再実行時やウィジェット操作時のパフォーマンスが向上します。
@st.cache_data()
def load_data():
    """
    Snowflakeのテーブルに接続し、データを取得してPandas DataFrameとして返します。
    """
    # アクティブセッションを使用してSnowflakeのテーブルを参照し、Pandas DataFrameに変換します。
    # 注: 元の変数名 'germany_sales_df' はコンテキストに対して紛らわしい可能性がありました。

    japan_sales_df = session.table("tb_101.analytics.japan_menu_item_sales_feb_2022").to_pandas()
    return japan_sales_df

# データを読み込む関数を呼び出します。キャッシュにより、初回以降は高速に動作します。
japan_sales = load_data()


# --- ウィジェットによるユーザーインタラクション ---

# ドロップダウンに表示するため、DataFrameからメニューアイテム名の一意なリストを取得します。
menu_item_names = japan_sales['MENU_ITEM_NAME'].unique().tolist()

# Streamlitのドロップダウンメニュー（selectbox）を作成します。
# ユーザーの選択は 'selected_menu_item' 変数に格納されます。
selected_menu_item = st.selectbox("Select a menu item", options=menu_item_names)


# --- データの準備 ---

# ユーザーが選択したメニューアイテムに一致する行のみにDataFrameをフィルタリングします。
menu_item_sales = japan_sales[japan_sales['MENU_ITEM_NAME'] == selected_menu_item]

# フィルタリングされたデータを 'DATE' でグループ化し、各日の 'ORDER_TOTAL' の合計を計算します。
daily_totals = menu_item_sales.groupby('DATE')['ORDER_TOTAL'].sum().reset_index()


# --- チャートの設定 ---

# 動的なY軸スケールを設定するため、売上値の範囲を計算します。
min_value = daily_totals['ORDER_TOTAL'].min()
max_value = daily_totals['ORDER_TOTAL'].max()

# チャートの最小値・最大値の上下に追加するマージンを計算します。
chart_margin = (max_value - min_value) / 2
y_margin_min = min_value - chart_margin
y_margin_max = max_value + chart_margin

# 折れ線グラフを作成します。
chart = alt.Chart(daily_totals).mark_line(
    point=True,     
    tooltip=True
).encode(
    x=alt.X('DATE:T',
            axis=alt.Axis(title='Date', format='%b %d'),
            title='Date'),
    y=alt.Y('ORDER_TOTAL:Q',
            axis=alt.Axis(title='Total Sales ($)'), 
            title='Total Daily Sales',
# Y軸に動的なパディングを追加するため、カスタムドメイン（範囲）を設定します。
            scale=alt.Scale(domain=[y_margin_min, y_margin_max]))
).properties(
    title=f'Total Daily Sales for Menu Item: {selected_menu_item}',
    height=500
)


# --- チャートの表示 ---

# Altairチャートを Streamlitアプリにレンダリングします。
# 'use_container_width=True' により、チャートはコンテナの全幅に拡張されます。
st.altair_chart(chart, use_container_width=True)

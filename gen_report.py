import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import matplotlib.dates as mdates
from datetime import datetime
import numpy as np

plt.rcParams['font.family'] = 'BIZ UDGothic'
plt.rcParams['font.size'] = 10
plt.rcParams['axes.titlesize'] = 13
plt.rcParams['axes.titleweight'] = 'bold'

SF_BLUE = '#29B5E8'
SF_DARK = '#11567F'
SF_NAVY = '#0D2B45'
SF_TEAL = '#49E5CB'
SF_ORANGE = '#FFAD5A'
SF_VIOLET = '#6E56CF'
SF_PINK = '#E54D9A'
LIGHT_GRAY = '#F5F5F7'
DARK_TEXT = '#1A1A2E'
PALETTE = [SF_BLUE, SF_TEAL, SF_ORANGE, SF_VIOLET, SF_PINK, '#A3A3A3', '#6B7280', '#D1D5DB']

# ── Data ──
monthly = {
    'month': ['2026-02', '2026-03', '2026-04', '2026-05\n(途中)'],
    'billed': [103.10, 126.78, 243.53, 17.07],
    'active_days': [17, 21, 25, 3],
}

daily_dates = [
    '2026-02-10','2026-02-12','2026-02-13','2026-02-16','2026-02-17','2026-02-18','2026-02-19','2026-02-20',
    '2026-02-24','2026-02-25','2026-02-26',
    '2026-03-02','2026-03-03','2026-03-04','2026-03-05','2026-03-06','2026-03-09','2026-03-10','2026-03-11',
    '2026-03-12','2026-03-13','2026-03-16','2026-03-17','2026-03-18','2026-03-19','2026-03-23','2026-03-24',
    '2026-03-25','2026-03-26','2026-03-27','2026-03-30','2026-03-31',
    '2026-04-01','2026-04-02','2026-04-03','2026-04-06','2026-04-07','2026-04-08','2026-04-09','2026-04-10',
    '2026-04-13','2026-04-14','2026-04-15','2026-04-16','2026-04-17','2026-04-18','2026-04-19','2026-04-20',
    '2026-04-21','2026-04-22','2026-04-23','2026-04-24','2026-04-25','2026-04-26','2026-04-27','2026-04-28',
    '2026-04-30',
    '2026-05-05','2026-05-07','2026-05-08',
]
daily_credits = [
    11.88,8.84,0.65,3,15.27,29.11,2.44,1.03,
    0.29,5.72,5.73,
    5.98,0.39,0.18,5.39,1.83,2.05,0.42,1.23,1.95,5.95,13.93,5.02,8.56,1.48,5.4,11.92,2.22,20.34,6.12,14.51,11.92,
    9.89,22.96,24.96,16.59,10.83,8.63,12.99,4.34,20.11,13.62,5.81,1.22,18.8,0.15,0.14,5.98,5.29,6.31,9.05,22.24,0.77,0.15,9.18,1.81,11.69,
    5.63,0.73,10.71,
]
daily_dt = [datetime.strptime(d, '%Y-%m-%d') for d in daily_dates]

wh_labels = ['WH 41409172', 'WH 41409264', 'WH 41409184', 'WH 41409136', 'Others']
wh_credits = [201.48, 147.03, 55.34, 54.71, 12.78]

dow_labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
dow_avg = [9.67, 7.25, 7.77, 8.06, 9.66, 0.46, 0.14]
dow_max = [20.11, 15.27, 29.11, 22.96, 24.96, 0.77, 0.15]

storage_dates_str = [
    '2026-04-11','2026-04-14','2026-04-17','2026-04-20','2026-04-25','2026-04-28',
    '2026-04-30','2026-05-01','2026-05-05','2026-05-08','2026-05-09','2026-05-10'
]
storage_tb = [6.347, 6.35, 6.358, 6.359, 6.663, 6.708, 6.622, 6.81, 6.726, 6.726, 6.886, 6.852]
storage_dt = [datetime.strptime(d, '%Y-%m-%d') for d in storage_dates_str]

wh_table = [
    ['WH 41409172', '201.48', '1,363.75', '41', '4.91', '2026-03-04', '2026-05-08'],
    ['WH 41409264', '147.03', '851.25', '23', '6.39', '2026-02-17', '2026-05-08'],
    ['WH 41409184', '55.34', '416.25', '23', '2.41', '2026-02-10', '2026-05-08'],
    ['WH 41409136', '54.71', '2,083.75', '53', '1.03', '2026-02-10', '2026-05-08'],
    ['WH 41409028', '4.47', '30.00', '3', '1.49', '2026-04-02', '2026-04-27'],
    ['WH 41409160', '4.28', '48.75', '14', '0.31', '2026-02-19', '2026-05-08'],
    ['WH 41409052', '2.50', '18.00', '8', '0.31', '2026-02-10', '2026-04-27'],
    ['WH 41409040', '1.53', '11.00', '2', '0.77', '2026-04-06', '2026-04-07'],
]

output_path = '/Users/hirokiwatari/repo/zero_to_handson/UI69109_Consumption_Report.pdf'

with PdfPages(output_path) as pdf:
    # ── Page 1: Cover + KPIs ──
    fig = plt.figure(figsize=(11.69, 8.27))
    fig.patch.set_facecolor(SF_NAVY)

    fig.text(0.5, 0.72, 'UI69109 (AWS Tokyo)', ha='center', va='center',
             fontsize=36, fontweight='bold', color='white')
    fig.text(0.5, 0.62, 'コンサンプション レポート', ha='center', va='center',
             fontsize=24, color=SF_TEAL)
    fig.text(0.5, 0.52, 'ENTERPRISE  |  awsapnortheast1  |  Org: VMDCIGG',
             ha='center', va='center', fontsize=13, color='#AAAAAA')
    fig.text(0.5, 0.45, f'Report Date: {datetime.now().strftime("%Y-%m-%d")}',
             ha='center', va='center', fontsize=11, color='#888888')

    kpi_data = [
        ('490.5', 'Total Billed Credits\n(90日間)', SF_BLUE),
        ('+92%', '4月 MoM 増加率\n(vs 3月)', SF_ORANGE),
        ('6.85 TB', 'Active Storage\n(直近)', SF_TEAL),
        ('8', 'ウェアハウス数\n(アクティブ)', SF_VIOLET),
    ]
    kpi_y = 0.18
    for i, (val, label, color) in enumerate(kpi_data):
        x = 0.13 + i * 0.22
        ax_kpi = fig.add_axes([x, kpi_y, 0.18, 0.15])
        ax_kpi.set_xlim(0, 1); ax_kpi.set_ylim(0, 1)
        ax_kpi.set_facecolor('#1A2A3A')
        for spine in ax_kpi.spines.values(): spine.set_visible(False)
        ax_kpi.set_xticks([]); ax_kpi.set_yticks([])
        ax_kpi.axhline(y=0.95, color=color, linewidth=3, xmin=0.1, xmax=0.9)
        ax_kpi.text(0.5, 0.65, val, ha='center', va='center', fontsize=22, fontweight='bold', color='white')
        ax_kpi.text(0.5, 0.22, label, ha='center', va='center', fontsize=9, color='#BBBBBB')

    pdf.savefig(fig, facecolor=fig.get_facecolor())
    plt.close()

    # ── Page 2: Monthly + WH Pie ──
    fig, axes = plt.subplots(1, 2, figsize=(11.69, 8.27))
    fig.patch.set_facecolor('white')
    fig.suptitle('コンピュート消費の概要', fontsize=18, fontweight='bold', color=SF_NAVY, y=0.96)

    ax1 = axes[0]
    bars = ax1.bar(monthly['month'], monthly['billed'], color=[SF_BLUE, SF_BLUE, SF_ORANGE, '#CCCCCC'],
                   edgecolor='white', linewidth=0.5, width=0.6)
    for bar, val, days in zip(bars, monthly['billed'], monthly['active_days']):
        ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 3,
                 f'{val:.1f}', ha='center', va='bottom', fontsize=11, fontweight='bold', color=DARK_TEXT)
        ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height()/2,
                 f'{days}日', ha='center', va='center', fontsize=9, color='white', fontweight='bold')
    ax1.set_title('月次 Billed Credits', fontsize=14, fontweight='bold', color=SF_NAVY, pad=15)
    ax1.set_ylabel('Credits', fontsize=11)
    ax1.set_facecolor(LIGHT_GRAY)
    ax1.spines['top'].set_visible(False); ax1.spines['right'].set_visible(False)
    ax1.grid(axis='y', alpha=0.3)

    ax2 = axes[1]
    explode = [0.03, 0.03, 0.03, 0.03, 0.06]
    wedges, texts, autotexts = ax2.pie(wh_credits, labels=wh_labels, autopct='%1.0f%%',
                                        colors=PALETTE[:5], explode=explode, startangle=90,
                                        textprops={'fontsize': 10})
    for t in autotexts: t.set_fontweight('bold'); t.set_fontsize(10)
    ax2.set_title('ウェアハウス別 消費割合（90日）', fontsize=14, fontweight='bold', color=SF_NAVY, pad=15)

    fig.tight_layout(rect=[0, 0, 1, 0.92])
    pdf.savefig(fig)
    plt.close()

    # ── Page 3: Daily trend ──
    fig, ax = plt.subplots(figsize=(11.69, 8.27))
    fig.patch.set_facecolor('white')
    ax.fill_between(daily_dt, daily_credits, alpha=0.3, color=SF_BLUE)
    ax.plot(daily_dt, daily_credits, color=SF_BLUE, linewidth=1.5)

    peak_idx = daily_credits.index(max(daily_credits))
    ax.annotate(f'Peak: {daily_credits[peak_idx]:.1f} cr\n({daily_dates[peak_idx]})',
                xy=(daily_dt[peak_idx], daily_credits[peak_idx]),
                xytext=(daily_dt[peak_idx], daily_credits[peak_idx] + 5),
                fontsize=9, fontweight='bold', color=SF_ORANGE,
                arrowprops=dict(arrowstyle='->', color=SF_ORANGE, lw=1.5),
                ha='center')

    avg_val = np.mean(daily_credits)
    ax.axhline(y=avg_val, color=SF_VIOLET, linestyle='--', alpha=0.7, linewidth=1)
    ax.text(daily_dt[-1], avg_val + 0.8, f'平均: {avg_val:.1f} cr/日', fontsize=9,
            color=SF_VIOLET, ha='right', fontweight='bold')

    ax.set_title('日次 Billed Credits 推移（過去90日）', fontsize=16, fontweight='bold', color=SF_NAVY, pad=15)
    ax.set_ylabel('Billed Credits', fontsize=11)
    ax.set_facecolor(LIGHT_GRAY)
    ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
    ax.grid(axis='y', alpha=0.3)
    ax.xaxis.set_major_formatter(mdates.DateFormatter('%m/%d'))
    ax.xaxis.set_major_locator(mdates.WeekdayLocator(interval=2))
    fig.autofmt_xdate()
    fig.tight_layout()
    pdf.savefig(fig)
    plt.close()

    # ── Page 4: DOW + Storage ──
    fig, axes = plt.subplots(1, 2, figsize=(11.69, 8.27))
    fig.patch.set_facecolor('white')
    fig.suptitle('利用パターンとストレージ', fontsize=18, fontweight='bold', color=SF_NAVY, y=0.96)

    ax3 = axes[0]
    x_pos = np.arange(len(dow_labels))
    bar_colors = [SF_BLUE]*5 + ['#CCCCCC']*2
    ax3.bar(x_pos, dow_avg, color=bar_colors, width=0.6, label='平均', alpha=0.85)
    ax3.scatter(x_pos, dow_max, color=SF_ORANGE, s=80, zorder=5, label='最大', edgecolors='white', linewidth=1)
    for i, (a, m) in enumerate(zip(dow_avg, dow_max)):
        ax3.text(i, a + 0.5, f'{a:.1f}', ha='center', va='bottom', fontsize=9, fontweight='bold', color=DARK_TEXT)
    ax3.set_xticks(x_pos); ax3.set_xticklabels(dow_labels)
    ax3.set_title('曜日別 平均消費パターン', fontsize=14, fontweight='bold', color=SF_NAVY, pad=15)
    ax3.set_ylabel('Credits', fontsize=11)
    ax3.legend(fontsize=9, loc='upper right')
    ax3.set_facecolor(LIGHT_GRAY)
    ax3.spines['top'].set_visible(False); ax3.spines['right'].set_visible(False)
    ax3.grid(axis='y', alpha=0.3)

    ax4 = axes[1]
    ax4.fill_between(storage_dt, storage_tb, alpha=0.3, color=SF_TEAL)
    ax4.plot(storage_dt, storage_tb, color=SF_TEAL, linewidth=2, marker='o', markersize=4)
    for i in [0, -1]:
        ax4.annotate(f'{storage_tb[i]:.2f} TB', xy=(storage_dt[i], storage_tb[i]),
                     xytext=(0, 10), textcoords='offset points', fontsize=9, fontweight='bold',
                     color=SF_DARK, ha='center')
    ax4.set_title('ストレージ推移 (Active TB)', fontsize=14, fontweight='bold', color=SF_NAVY, pad=15)
    ax4.set_ylabel('TB', fontsize=11)
    ax4.set_ylim(6.2, 7.0)
    ax4.set_facecolor(LIGHT_GRAY)
    ax4.spines['top'].set_visible(False); ax4.spines['right'].set_visible(False)
    ax4.grid(axis='y', alpha=0.3)
    ax4.xaxis.set_major_formatter(mdates.DateFormatter('%m/%d'))
    fig.autofmt_xdate()
    fig.tight_layout(rect=[0, 0, 1, 0.92])
    pdf.savefig(fig)
    plt.close()

    # ── Page 5: WH Detail Table ──
    fig = plt.figure(figsize=(11.69, 8.27))
    fig.patch.set_facecolor('white')
    fig.text(0.5, 0.93, 'ウェアハウス別 詳細（過去90日）', ha='center', fontsize=18, fontweight='bold', color=SF_NAVY)

    col_headers = ['Warehouse ID', 'Billed\nCredits', 'Server\nCredits', 'Active\nDays', 'Avg Daily\nCredits', 'First Seen', 'Last Seen']
    ax_t = fig.add_axes([0.05, 0.15, 0.9, 0.7])
    ax_t.axis('off')

    table = ax_t.table(cellText=wh_table, colLabels=col_headers, loc='center',
                       cellLoc='center', colWidths=[0.16, 0.12, 0.12, 0.10, 0.12, 0.14, 0.14])
    table.auto_set_font_size(False)
    table.set_fontsize(10)
    table.scale(1, 1.8)

    for (row, col), cell in table.get_celld().items():
        cell.set_edgecolor('#E0E0E0')
        if row == 0:
            cell.set_facecolor(SF_NAVY)
            cell.set_text_props(color='white', fontweight='bold', fontsize=9)
        elif row % 2 == 0:
            cell.set_facecolor('#F8F9FA')
        else:
            cell.set_facecolor('white')

    for i, row_data in enumerate(wh_table):
        credit_val = float(row_data[1])
        if credit_val > 100:
            table[(i+1, 1)].set_text_props(fontweight='bold', color='#C0392B')

    fig.text(0.05, 0.08,
             '注: WH 41409136 は Server Credits が 2,083 と突出（Billed は低い）→ 長時間アイドル稼働の可能性あり\n'
             '    WH 41409172 が全体の 43% を占める最大消費源',
             fontsize=9, color='#666666', va='top')

    pdf.savefig(fig)
    plt.close()

    # ── Page 6: Summary ──
    fig = plt.figure(figsize=(11.69, 8.27))
    fig.patch.set_facecolor(SF_NAVY)

    fig.text(0.5, 0.85, 'サマリー & 推奨アクション', ha='center', fontsize=24, fontweight='bold', color='white')

    findings = [
        ('コンピュート', '4月は 243.5 cr と前月比 +92% 増加。WH 41409172 (43%) と WH 41409264 (31%) が支配的。'),
        ('利用パターン', '平日中心の利用（月〜金: 平均 8.5 cr/日）。土日はほぼゼロ。AUTO_SUSPEND設定の確認を推奨。'),
        ('ストレージ', 'Active Storage 6.85 TB、Logical 18.5 TB。30日で +0.5TB 増加傾向。Failsafe/Time Travel はゼロ。'),
        ('ガバナンス', 'Tagging のみ微量利用。DDM / RAP / DMF / Classification は未使用。'),
        ('Cortex AI', '直近30日間の Cortex Analyst / SPCS 利用なし。'),
    ]

    y_start = 0.72
    for i, (title, desc) in enumerate(findings):
        y = y_start - i * 0.11
        fig.text(0.08, y, f'●  {title}', fontsize=13, fontweight='bold', color=SF_TEAL)
        fig.text(0.08, y - 0.035, f'    {desc}', fontsize=10, color='#CCCCCC')

    actions = [
        '① WH 41409136 のアイドル時間を調査し、AUTO_SUSPEND を短縮',
        '② WH 41409172 の大量消費クエリを特定・最適化',
        '③ ガバナンス機能（DDM, Classification）の活用検討',
    ]
    fig.text(0.08, 0.18, '推奨アクション', fontsize=14, fontweight='bold', color=SF_ORANGE)
    for i, action in enumerate(actions):
        fig.text(0.08, 0.13 - i * 0.04, action, fontsize=10, color='white')

    pdf.savefig(fig, facecolor=fig.get_facecolor())
    plt.close()

print(f'PDF created: {output_path}')

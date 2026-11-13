"""
ECON 20 Project - Table 1: means + balance tests, in the Dynarski (2003) Table 1 layout.
  Columns (1)-(4): means [SD] for California / other states (excl. WA), before / after the law
  Column  (5): diff-in-diff coefficient on California x Post, (clustered SE)
  Column  (6): California minus other states BEFORE the law, (clustered SE)
Means come from final_data.dta (built by 01_build_data.do).
Coefficients come from the Stata output of 02_table1_means.do
  (output/balance_did.csv and output/balance_prelaw.csv). If those are not there yet,
  the Python preview (output/balance_python_preview.csv) is used and the table says so.
Output: output/Table1_means_balance.xlsx
"""
import os, pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Font, Alignment, Border, Side

os.chdir(os.path.dirname(os.path.abspath(__file__)) + "/..")
d = pd.read_stata("final_data.dta")
d = d[(d.mainwindow == 1) & (d.wa == 0)]

if os.path.exists("output/balance_did.csv") and os.path.exists("output/balance_prelaw.csv"):
    did = pd.read_csv("output/balance_did.csv").set_index("variable")
    pre = pd.read_csv("output/balance_prelaw.csv").set_index("variable")
    coef = pd.DataFrame({"did_b3": did.did_b3, "did_se": did.did_se,
                         "pre_diff": pre["diff"], "pre_se": pre.se})
    source = "Stata (02_table1_means.do)"
else:
    coef = pd.read_csv("output/balance_python_preview.csv").set_index("variable")
    source = "PYTHON PREVIEW - rerun 02_table1_means.do, then this script, to replace"

panels = [
  ("A. Outcome", [
    ('lnmktcap', 'Ln(Market Cap)', None, '0.000'),
    ('mktcap', 'Market Cap', '($ millions)', '#,##0')]),
  ("B. Firm Characteristics (balance test)", [
    ('lnassets', 'Ln(Total Assets)', None, '0.000'),
    ('roa', 'Net Income /', 'Total Assets', '0.000'),
    ('leverage', 'Total Liabilities /', 'Total Assets', '0.000'),
    ('multinational', 'Multinational', '(foreign income)', '0.000'),
    ('age', 'Years Since IPO', None, '0.00'),
    ('nyse', 'Listed on NYSE', None, '0.000'),
    ('tech', 'Tech Sector', '(GICS 45)', '0.000')]),
  ("C. Board Composition (first stage)", [
    ('boardsize', 'Board Size', None, '0.00'),
    ('women', 'Women on Board', None, '0.000'),
    ('zerowomen', 'No Women', 'on Board', '0.000')]),
]
cells = [((d.ca == 1) & (d.post == 0)), ((d.ca == 0) & (d.post == 0)),
         ((d.ca == 1) & (d.post == 1)), ((d.ca == 0) & (d.post == 1))]

F = 'Calibri'; thin = Side(style='thin')
wb = Workbook(); ws = wb.active; ws.title = 'Table 1'
ws.column_dimensions['A'].width = 22
for c in 'BCDEFG': ws.column_dimensions[c].width = 13.5
def put(r, c, v, fmt=None, bold=False, italic=False, h='center', underline=None, size=11):
    x = ws.cell(row=r, column=c, value=v)
    x.font = Font(name=F, size=size, bold=bold, italic=italic, underline=underline)
    x.alignment = Alignment(horizontal=h, vertical='center', wrap_text=True)
    if fmt: x.number_format = fmt
    return x

put(1, 1, 'Table 1. Means and Balance Tests, California vs. Other States, Before and After SB 826', bold=True, h='left', size=12)
ws.merge_cells('A1:G1')
put(3, 2, 'Before the Law', underline='single'); ws.merge_cells('B3:C3')
put(3, 4, 'After the Law', underline='single'); ws.merge_cells('D3:E3')
put(3, 6, 'Difference-in-', underline=None); put(3, 7, 'Difference', underline=None)
heads = ['California', 'Other States', 'California', 'Other States', 'Differences', 'Before Law']
for j, t in enumerate(heads): put(4, 2 + j, t)
for j in range(6): put(5, 2 + j, f'({j+1})')
for c in range(1, 8): ws.cell(row=5, column=c).border = Border(bottom=thin)

r = 7
for title, rows in panels:
    put(r, 1, title, italic=True, h='left'); ws.merge_cells(start_row=r, start_column=1, end_row=r, end_column=7); r += 1
    for var, l1, l2, fmt in rows:
        put(r, 1, l1, h='left'); put(r + 1, 1, ('  ' + l2) if l2 else None, h='left')
        for j, c in enumerate(cells):
            x = d[c][var].dropna()
            put(r, 2 + j, float(x.mean()), fmt)
            put(r + 1, 2 + j, float(x.std()), '"["' + fmt + '"]"')
        put(r, 6, float(coef.loc[var, 'did_b3']), fmt)
        put(r + 1, 6, float(coef.loc[var, 'did_se']), '"("' + fmt + '")"')
        put(r, 7, float(coef.loc[var, 'pre_diff']), fmt)
        put(r + 1, 7, float(coef.loc[var, 'pre_se']), '"("' + fmt + '")"')
        r += 2
    r += 1
put(r, 1, 'Firm-Years', h='left'); put(r + 1, 1, 'Firms', h='left')
for j, c in enumerate(cells):
    put(r, 2 + j, int(c.sum()), '#,##0'); put(r + 1, 2 + j, int(d[c].gvkey.nunique()), '#,##0')
put(r, 6, int(len(d)), '#,##0'); put(r, 7, int((d.post == 0).sum()), '#,##0')
r += 2
for c in range(1, 8): ws.cell(row=r - 1, column=c).border = Border(bottom=thin)

note = ("Notes: Data from Compustat North America Fundamentals Annual and BoardEx North America (WRDS). "
        "Sample: US-headquartered firms listed on NYSE, AMEX or Nasdaq, excluding funds and shell companies "
        "(SIC 67xx), fiscal years ending Jan 2010 - Dec 2019; Washington firms excluded. 'Before' = fiscal year "
        "ended before 1 Oct 2018; 'After' = fiscal year ended 1 Oct 2018 - 31 Dec 2019. Columns (1)-(4): means, "
        "standard deviations in brackets. Column (5): coefficient on California x After from a regression of the "
        "row variable on California, After and California x After. Column (6): coefficient on California from a "
        "regression of the row variable on California, before the law only. Standard errors in parentheses, "
        "clustered by firm. Board variables available for firm-years matched to BoardEx (about 80%). Net income / "
        "assets and liabilities / assets winsorized at the 1st and 99th percentiles. Headquarters state is the "
        "current state reported by Compustat. Column (5) N = all firm-years; column (6) N = before-law firm-years "
        "(both with non-missing values of the row variable).")
put(r, 1, note, h='left', size=10); ws.merge_cells(start_row=r, start_column=1, end_row=r, end_column=7)
ws.cell(row=r, column=1).alignment = Alignment(horizontal='left', vertical='top', wrap_text=True)
ws.row_dimensions[r].height = 125
ws.cell(row=r + 2, column=1, value='Coefficients from: ' + source).font = Font(name=F, size=9, italic=True, color='808080')
ws.sheet_view.showGridLines = False
ws.sheet_properties.pageSetUpPr.fitToPage = True
ws.page_setup.orientation = 'landscape'; ws.page_setup.fitToWidth = 1; ws.page_setup.fitToHeight = 1
wb.save('output/Table1_means_balance.xlsx')
print('saved output/Table1_means_balance.xlsx; coefficients from', source)

"""
ECON 20 Project: California SB 826 (board gender quota) and firm value
Program 3: FORMAT TABLE 1 (MEANS AND BALANCE TEST) FOR THE PAPER

Layout follows Dynarski (2003), Table 1: four means columns (before/after the
law x Texas/California), then the pre-law California-Texas difference and the
difference-in-differences, with standard deviations or standard errors in
parentheses under each number. Nothing is computed here; every number comes
from output/table1_balance.csv, written by 02_balance_test.do.

Author: Ansh   (file: code/03_table1_format.py)
Input:  output/table1_balance.csv
Output: output/Table1_means_balance.xlsx
Run:    python3 code/03_table1_format.py   (from any folder; paths are relative
        to this file). Needs pandas and openpyxl. Also run by code/00_master.do.
"""

from pathlib import Path

import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, Side
from openpyxl.utils import get_column_letter

PROJ = Path(__file__).resolve().parents[1]  # project folder (code/..)
IN = PROJ / "output" / "table1_balance.csv"
OUT = PROJ / "output" / "Table1_means_balance.xlsx"

# row label, decimals, indent (True for the "share blank" rows)
ROWS = [
    ("Panel A. Outcome and board composition", None, None),
    ("lnmktcap",      "Ln(market cap)",                       3, False),
    ("women",         "Women on board",                       3, False),
    ("zerowomen",     "No women on board",                    3, False),
    ("Panel B. Firm characteristics (balance test)", None, None),
    ("lnassets",      "Ln(total assets)",                     3, False),
    ("roa",           "Net income / total assets",            3, False),
    ("leverage",      "Total liabilities / total assets",     3, False),
    ("multinational", "Multinational (foreign income)",       3, False),
    ("pifo_missing",  "Foreign income not reported",          3, True),
    ("age",           "Years since IPO",                      2, False),
    ("age_missing",   "IPO date missing",                     3, True),
    ("nyse",          "Listed on NYSE",                       3, False),
    ("tech",          "Tech sector (GICS 45)",                3, False),
    ("energy",        "Oil and gas (SIC 13, 29)",             3, False),
    ("boardsize",     "Board size",                           2, False),
    ("pharma",        "Pharma or biotech (SIC 2833-2836)",    3, False),
]

NOTES = (
    "Notes: Sample is firms headquartered in California or Texas on 30 September "
    "2018, listed on the NYSE, AMEX or Nasdaq, excluding funds, trusts and shell "
    "companies (SIC 67xx) and firm-years with under $1 million of total assets. "
    "\"Before\" is fiscal years ending June 2010 to September 2018; \"After\" is "
    "fiscal years ending October 2018 to December 2019. Columns (1)-(4) report "
    "unweighted means with standard deviations in brackets. Column (5) is the "
    "coefficient on a California dummy from a regression of the row variable on "
    "that dummy, before-the-law sample only. Column (6) is the coefficient on "
    "California x After from a regression of the row variable on California, "
    "After and their interaction, full sample. Standard errors in columns (5) and "
    "(6) are in parentheses and clustered by firm. Market cap is fiscal-year-end "
    "price times shares outstanding. Multinational equals 1 if Compustat reports "
    "nonzero foreign pretax income; blank values are counted as zero, and the "
    "share blank is shown in the row below. Years since IPO is missing where "
    "Compustat has no IPO date (mostly older firms); the share missing is shown "
    "in the row below. Board variables are from BoardEx and are available for "
    "85 percent of firm-years. Sources: Compustat North America Fundamentals "
    "Annual and BoardEx North America, via WRDS."
)


def fmt(x, d):
    if pd.isna(x):
        return ""
    return f"{x:,.{d}f}"


def main():
    t = pd.read_csv(IN).set_index("variable")

    wb = Workbook()
    ws = wb.active
    ws.title = "Table 1"

    font = Font(name="Times New Roman", size=10)
    bold = Font(name="Times New Roman", size=10, bold=True)
    ital = Font(name="Times New Roman", size=10, italic=True)
    center = Alignment(horizontal="center", vertical="center", wrap_text=True)
    left = Alignment(horizontal="left", vertical="center")
    thin = Side(style="thin")
    double = Side(style="double")

    # Title
    ws.merge_cells("A1:G1")
    ws["A1"] = "Table 1. Means and Balance Test: California vs. Texas, Before and After SB 826"
    ws["A1"].font = bold
    ws["A1"].alignment = center

    # Header rows
    ws.merge_cells("B3:C3")
    ws["B3"] = "Before the law"
    ws.merge_cells("D3:E3")
    ws["D3"] = "After the law"
    ws["F3"] = ""
    ws["G3"] = ""
    heads = ["", "Texas", "California", "Texas", "California",
             "CA - TX\nbefore", "Difference-\nin-differences"]
    nums = ["", "(1)", "(2)", "(3)", "(4)", "(5)", "(6)"]
    for j, (h, n) in enumerate(zip(heads, nums), start=1):
        ws.cell(row=4, column=j, value=h)
        ws.cell(row=5, column=j, value=n)
    for r in (3, 4, 5):
        for j in range(1, 8):
            c = ws.cell(row=r, column=j)
            c.font = font
            c.alignment = center
    for j in (2, 3, 4, 5):
        ws.cell(row=3, column=j).border = Border(bottom=thin)
    for j in range(1, 8):
        ws.cell(row=2, column=j).border = Border(top=double)
        ws.cell(row=5, column=j).border = Border(bottom=thin)

    # Body
    r = 6
    for spec in ROWS:
        if spec[1] is None:
            ws.cell(row=r, column=1, value=spec[0]).font = ital
            r += 1
            continue
        var, label, d, indent = spec
        x = t.loc[var]
        lab = ("    " if indent else "") + label
        ws.cell(row=r, column=1, value=lab).font = ital if indent else font
        ws.cell(row=r, column=1).alignment = left
        means = [x["mean_tx"], x["mean_ca"], x["mean_tx_post"], x["mean_ca_post"]]
        sds = [x["sd_tx"], x["sd_ca"], x["sd_tx_post"], x["sd_ca_post"]]
        for j, (m, s) in enumerate(zip(means, sds), start=2):
            ws.cell(row=r, column=j, value=fmt(m, d))
            ws.cell(row=r + 1, column=j, value=f"[{fmt(s, d)}]")
        if not pd.isna(x["diff"]):
            ws.cell(row=r, column=6, value=fmt(x["diff"], d))
            ws.cell(row=r + 1, column=6, value=f"({fmt(x['diff_se'], d)})")
            ws.cell(row=r, column=7, value=fmt(x["did"], d))
            ws.cell(row=r + 1, column=7, value=f"({fmt(x['did_se'], d)})")
        for rr in (r, r + 1):
            for j in range(2, 8):
                c = ws.cell(row=rr, column=j)
                c.font = font
                c.alignment = center
        r += 2

    # Counts
    for key, label in (("firm_years", "Firm-years"), ("firms", "Firms")):
        x = t.loc[key]
        ws.cell(row=r, column=1, value=label).font = font
        vals = [x["mean_tx"], x["mean_ca"], x["mean_tx_post"], x["mean_ca_post"],
                x["diff_n"], x["did_n"]]
        for j, v in enumerate(vals, start=2):
            c = ws.cell(row=r, column=j, value=fmt(v, 0))
            c.font = font
            c.alignment = center
        r += 1
    for j in range(1, 8):
        ws.cell(row=r - 1, column=j).border = Border(bottom=thin)

    # Notes
    r += 1
    ws.merge_cells(start_row=r, start_column=1, end_row=r + 9, end_column=7)
    c = ws.cell(row=r, column=1, value=NOTES)
    c.font = Font(name="Times New Roman", size=9)
    c.alignment = Alignment(wrap_text=True, vertical="top")

    ws.column_dimensions["A"].width = 34
    for j in range(2, 8):
        ws.column_dimensions[get_column_letter(j)].width = 13
    ws.row_dimensions[4].height = 30

    wb.save(OUT)
    print(f"wrote {OUT.relative_to(PROJ)}")


if __name__ == "__main__":
    main()
